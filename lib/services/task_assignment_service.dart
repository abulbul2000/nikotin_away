import '../models/adaptive_task_models.dart';
import '../models/task_assignment.dart';
import 'android_watchdog_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';
import 'task_delivery_gate.dart';

/// What a caller (foreground UI or the background isolate) still has to do
/// after [TaskAssignmentService.handleTaskAction] applies a state
/// transition. Only [openSosPage]/[openSleepRoutinePage] need a UI —
/// everything else is already fully handled by the time this returns.
enum TaskActionFollowUp { none, openSosPage, openSleepRoutinePage }

/// Notification/overlay action ids for a mandatory task.
///
/// Duplicated in value (not import) from `NotificationService`'s private
/// `_actionXxx` constants — those stay private because they are also baked
/// into `AndroidNotificationAction` wiring that lives there, and re-exporting
/// them would make this the wrong place to look for their real definition.
/// The values themselves are notification-payload/native-bridge contracts
/// and cannot change independently in either file.
class TaskActionId {
  static const String done = 'task_done';
  static const String notNow = 'task_not_now';
  static const String decline = 'task_decline';
  static const String sos = 'task_sos';
  static const String postpone5 = 'task_postpone_5';
  static const String postpone10 = 'task_postpone_10';
  static const String postpone15 = 'task_postpone_15';
  static const String confirmSmokedYes = 'confirm_smoked_yes';
  static const String confirmSmokedNo = 'confirm_smoked_no';

  static const Map<String, int> postponeMinutesByAction = {
    postpone5: 5,
    postpone10: 10,
    postpone15: 15,
  };
}

/// Where a planned task first becomes a real, trackable row.
///
/// The daily plan (`DisciplineProtocolService.buildDailyAdaptivePlan`) only
/// ever produced in-memory `AdaptiveTaskPlanItem`s that notifications were
/// scheduled from directly — the `task_assignments` table existed but
/// nothing ever inserted into it, so every downstream read
/// (`_taskAllowanceFor`, `transitionTaskAssignment`) silently no-opped. This
/// is the one place that turns a plan item into a row other code can act on.
class TaskAssignmentService {
  TaskAssignmentService(this._storage);

  final StorageService _storage;

  /// Ensures every item in [items] has a corresponding `task_assignments`
  /// row for [planDate], without duplicating rows already created by an
  /// earlier call this same day (app reopened, plan recomputed, etc).
  ///
  /// Matched by canonicalTitle+scheduledAt — the same pairing
  /// `AdaptiveTaskPlanItem`s are naturally unique by, since the plan never
  /// places two items at the same moment.
  ///
  /// Returns every row for [planDate] (both newly-created and already
  /// existing), so a caller scheduling notifications from the same [items]
  /// list can look each one's row id up by canonicalTitle+scheduledAt and
  /// thread it through as the watchdogId — see
  /// `NotificationService.scheduleFirstTaskTriggerNotification`'s
  /// `taskAssignmentId` parameter.
  Future<List<TaskAssignment>> planDailyTasks({
    required DateTime planDate,
    required List<AdaptiveTaskPlanItem> items,
  }) async {
    if (items.isEmpty) {
      return const [];
    }
    final existing = await _storage.loadTaskAssignmentsForDay(planDate);
    final existingKeys = existing
        .map((task) => _matchKey(task.canonicalTitle, task.scheduledAt))
        .toSet();

    final planDateKey = _planDateKey(planDate);
    final created = <TaskAssignment>[];
    for (final item in items) {
      final key = _matchKey(item.taskTitle, item.scheduledAt);
      if (existingKeys.contains(key)) {
        continue;
      }
      final task = TaskAssignment(
        id: _generateId(item),
        planDate: planDateKey,
        canonicalTitle: item.taskTitle,
        durationMinutes: item.durationMinutes,
        scheduledAt: item.scheduledAt,
        state: TaskLifecycleState.planned,
        isCheckIn: item.isCheckIn,
        taskKind: item.taskKind,
      );
      await _storage.saveTaskAssignment(task);
      created.add(task);
      existingKeys.add(key);
    }
    return [...existing, ...created];
  }

  /// Applies [TaskDeliveryGate]'s two-task queue limit to whatever is
  /// currently sitting in `pendingDelivery` (tasks the native delivery gate
  /// held back for DND/gaming/a call and hasn't retried into `delivered`
  /// yet).
  ///
  /// Called from the foreground, where a Dart isolate is actually running —
  /// the native `TaskTriggerReceiver`/`DeliveryGateEvaluator` retry loop is
  /// the one enforcing this while the app is closed (see
  /// TaskTriggerReceiver.kt's own queue handling). This is the app-open
  /// backstop for the same rule.
  Future<void> enforceDeliveryQueueLimit() async {
    final open = await _storage.loadOpenTaskAssignments();
    final pending = open
        .where((task) => task.state == TaskLifecycleState.pendingDelivery)
        .toList();
    final decision = TaskDeliveryGate.decide(pending);
    for (final task in decision.toExpire) {
      await _storage.transitionTaskAssignment(
        id: task.id,
        state: TaskLifecycleState.expired,
      );
    }
  }

  /// Drains watchdog ids `TaskTriggerReceiver.kt`'s own delivery-gate queue
  /// limit expired natively (app closed, two or more tasks blocked by the
  /// same DND/gaming stretch) and closes the matching rows out here too.
  ///
  /// Matched by id, not canonicalTitle — the native side only ever learns a
  /// task's watchdogId, and `scheduleFirstTaskTriggerNotification` threads
  /// the `task_assignments` row id through as that watchdogId precisely so
  /// this lookup works even when two tasks share a title.
  Future<void> syncPendingDeliveryExpirationsFromNative() async {
    final rows =
        await AndroidWatchdogService.consumePendingDeliveryExpirations();
    await applyPendingDeliveryExpirations(rows);
  }

  /// The applying half of [syncPendingDeliveryExpirationsFromNative], split
  /// out so it can be exercised with a canned [rows] list — the native
  /// consume call itself always returns empty off-device (no platform
  /// channel in tests), which would make the transition logic untestable
  /// otherwise.
  Future<void> applyPendingDeliveryExpirations(
    List<Map<String, dynamic>> rows,
  ) async {
    for (final row in rows) {
      final watchdogId = row['watchdogId']?.toString();
      if (watchdogId == null || watchdogId.isEmpty) {
        continue;
      }
      await _storage.transitionTaskAssignment(
        id: watchdogId,
        state: TaskLifecycleState.expired,
      );
    }
  }

  /// Drains the delivery gate's own record of "held this task back, and
  /// why" (TaskTriggerReceiver.kt's DeliveryGateStore — DND/game/call
  /// blocking a task's alarm while the app was closed) and applies it to
  /// the matching `task_assignments` row. Matched by watchdogId for the
  /// same reason [syncPendingDeliveryExpirationsFromNative] is: the native
  /// side only ever learns a task's watchdogId, and
  /// `scheduleFirstTaskTriggerNotification` threads the row id through as
  /// that watchdogId precisely so this lookup works.
  ///
  /// The task itself is never lost by a deferral — TaskTriggerReceiver
  /// re-arms its own alarm and still delivers it once the block clears or
  /// the 90-minute cap is hit — this only records that the deferral
  /// happened, which is what makes gateDeferCount/gateReason on the row
  /// mean anything.
  Future<void> syncDeliveryDeferralsFromNative() async {
    final rows = await AndroidWatchdogService.consumeDeliveryDeferrals();
    await applyDeliveryDeferrals(rows);
  }

  /// The applying half of [syncDeliveryDeferralsFromNative], split out for
  /// the same testability reason [applyPendingDeliveryExpirations] is.
  Future<void> applyDeliveryDeferrals(List<Map<String, dynamic>> rows) async {
    for (final row in rows) {
      final watchdogId = row['watchdogId']?.toString();
      final reason = row['reason']?.toString();
      if (watchdogId == null || watchdogId.isEmpty) {
        continue;
      }
      await _storage.transitionTaskAssignment(
        id: watchdogId,
        state: TaskLifecycleState.pendingDelivery,
        gateReason: reason,
      );
    }
  }

  /// The single place a task-notification action (Kabul Et / Ertele /
  /// Reddet / SOS / the "did you smoke?" answer) is decided.
  ///
  /// Used to be two near-duplicate switches: `notification_service.dart`'s
  /// `_handleActionWithoutUi` (ran when nothing was listening — app closed
  /// or backgrounded) and `home_page.dart`'s `_handleTaskNotificationAction`
  /// (ran whenever `HomePage` was subscribed to the action stream). They had
  /// drifted apart — the foreground one never handled decline, SOS, or the
  /// smoked-confirmation actions at all, so pressing those while the app was
  /// open silently did nothing. This is their merged replacement; both call
  /// sites now go through here.
  ///
  /// [canonicalTitle] is the `ADAPTIVE_NO_SMOKE:<minutes>` form used to
  /// look up the `task_assignments` row; [taskTitle] is what a caller
  /// displays. Returns what the caller still needs a UI for, if anything.
  Future<TaskActionFollowUp> handleTaskAction({
    required String canonicalTitle,
    required String taskTitle,
    required String actionId,
  }) async {
    if (canonicalTitle.isEmpty || actionId.isEmpty) {
      return TaskActionFollowUp.none;
    }

    if (actionId == TaskActionId.done) {
      final existing = await _storage.loadLatestTaskAssignmentByTitle(
        canonicalTitle,
      );
      if (isComposite(existing?.taskKind ?? TaskKind.noSmokeWindow)) {
        // The pre-sleep routine has no countdown or barrier to run and no
        // separate confirmation prompt — accepting it just hands the user
        // straight into SleepRoutinePage, which reports its own completion
        // via [completeSleepRoutine] once the report step is closed.
        await _transitionTask(canonicalTitle, TaskLifecycleState.accepted);
        return TaskActionFollowUp.openSleepRoutinePage;
      }

      final delay = resolveInitialTaskDelay(canonicalTitle);
      // Acceptance itself is already durably recorded on the task_assignments
      // row via the transition below (state=accepted, barrierStartedAt) --
      // writing a second 'started' row into TaskHistory served no reader and
      // only meant every accepted task, win or lose, silently added one
      // permanent "not completed" entry to the risk-scoring history.
      await _transitionTask(canonicalTitle, TaskLifecycleState.accepted);
      await NotificationService.showTaskTimerStartedNotification(
        taskTitle: canonicalTitle,
        duration: delay,
      );
      // The end-of-window question, asked as "did you smoke?".
      await NotificationService.scheduleTaskConfirmationPrompt(
        taskTitle: canonicalTitle,
        delay: delay,
      );
      // A quieter repeat of the same question if the first one never gets
      // answered — the app-open check in syncBarrierResolutionOnStartup
      // shares the same deadline and closes the task out as barrierUnknown
      // if the user never sees either notification.
      await NotificationService.scheduleBarrierResolutionReminder(
        taskTitle: canonicalTitle,
        delay: delay,
      );
      return TaskActionFollowUp.none;
    }

    if (actionId == TaskActionId.notNow) {
      await NotificationService.showPostponeChoiceNotification(
        taskTitle: canonicalTitle,
      );
      return TaskActionFollowUp.none;
    }

    final postponeChosen = TaskActionId.postponeMinutesByAction[actionId];
    if (postponeChosen != null) {
      await _transitionTask(
        canonicalTitle,
        TaskLifecycleState.postponed,
        postponeMinutes: postponeChosen,
      );
      await NotificationService.scheduleFirstTaskTriggerNotification(
        taskDescription: canonicalTitle,
        delay: Duration(minutes: postponeChosen),
      );
      return TaskActionFollowUp.none;
    }

    if (actionId == TaskActionId.decline) {
      // Scored as smoking, per the agreed rule: declining is treated as
      // intending to smoke, so the barrier doesn't keep growing on the
      // strength of tasks that were simply turned down.
      await _transitionTask(canonicalTitle, TaskLifecycleState.failedDeclined);
      return TaskActionFollowUp.none;
    }

    if (actionId == TaskActionId.sos) {
      // Suspended, not finished — the breathing exercise runs and hands the
      // user back to this same task afterwards.
      await _transitionTask(canonicalTitle, TaskLifecycleState.sosActive);
      return TaskActionFollowUp.openSosPage;
    }

    // The end-of-window answer. "Did you smoke?" — so yes is the failure.
    // Getting this backwards would invert every outcome the learning engine
    // ever records, which is why these ids are distinct from the older
    // followup pair rather than reused.
    if (actionId == TaskActionId.confirmSmokedYes) {
      await _transitionTask(canonicalTitle, TaskLifecycleState.failedSmoked);
      await NotificationService.cancelBarrierResolutionReminder(canonicalTitle);
      // An admission is also a real cigarette, so it belongs in the same
      // table the quick-log button writes to — otherwise the risky-hour
      // ranking never learns about the ones admitted this way.
      await _storage.logSmokingNow();
      return TaskActionFollowUp.none;
    }
    if (actionId == TaskActionId.confirmSmokedNo) {
      await _transitionTask(canonicalTitle, TaskLifecycleState.succeeded);
      await NotificationService.cancelBarrierResolutionReminder(canonicalTitle);
      return TaskActionFollowUp.none;
    }

    return TaskActionFollowUp.none;
  }

  /// Moves the `task_assignments` row for [canonicalTitle] to [state].
  ///
  /// A no-op when nothing matches: tasks issued before this table was wired
  /// up have no row, and should keep working through whatever older path
  /// they already used rather than throwing here.
  Future<void> _transitionTask(
    String canonicalTitle,
    String state, {
    int? postponeMinutes,
  }) async {
    try {
      final task = await _storage.loadLatestTaskAssignmentByTitle(
        canonicalTitle,
      );
      if (task == null) {
        return;
      }
      await _storage.transitionTaskAssignment(
        id: task.id,
        state: state,
        postponeMinutes: postponeMinutes,
      );
    } catch (_) {
      // Best effort — never let bookkeeping swallow the user's answer.
    }
  }

  /// Closes out the pre-sleep routine once its final report step is
  /// dismissed. Called from `SleepRoutinePage` itself — not a notification
  /// action, since accepting the task already handed the user into the page
  /// rather than starting a countdown/confirmation like a normal task.
  Future<void> completeSleepRoutine(String canonicalTitle) =>
      _transitionTask(canonicalTitle, TaskLifecycleState.succeeded);

  /// Whether a task of this kind is a "composite" — a multi-step in-app flow
  /// (see [TaskKind.sleepRoutine]) rather than a timed no-smoking window.
  /// Composite tasks skip the countdown/confirmation-prompt machinery in
  /// [handleTaskAction]'s `done` branch entirely.
  static bool isComposite(String taskKind) => taskKind == TaskKind.sleepRoutine;

  /// The one-per-day pre-sleep routine plan item: breath test, cough test,
  /// an optional smoking-count discrepancy question, then a daily report.
  /// [sleepAt] is the effective bedtime the daily plan already resolved;
  /// the routine itself starts an hour before it. `durationMinutes: 0`
  /// because — unlike [TaskKind.noSmokeWindow] — completing it opens
  /// `SleepRoutinePage` rather than starting a barrier countdown.
  static AdaptiveTaskPlanItem buildSleepRoutinePlanItem({
    required DateTime sleepAt,
  }) {
    return AdaptiveTaskPlanItem(
      scheduledAt: sleepAt.subtract(const Duration(hours: 1)),
      durationMinutes: 0,
      taskTitle: sleepRoutineCanonicalTitle,
      taskKind: TaskKind.sleepRoutine,
    );
  }

  /// How long a task's no-smoking window lasts, parsed from its title.
  ///
  /// The canonical `ADAPTIVE_NO_SMOKE:<minutes>` form is tried first; the
  /// looser minute/hour-word patterns exist for older or localized titles
  /// that don't follow it.
  static Duration resolveInitialTaskDelay(String taskTitle) {
    final adaptiveCanonical = RegExp(
      r'^ADAPTIVE_NO_SMOKE:(\d+)$',
      caseSensitive: false,
    ).firstMatch(taskTitle.trim());
    if (adaptiveCanonical != null) {
      final minutes = int.tryParse(adaptiveCanonical.group(1) ?? '');
      if (minutes != null && minutes > 0) {
        return Duration(minutes: minutes);
      }
    }

    final minuteMatch = RegExp(
      r'(\d+)\s*(dakika|minute|minutes|min)',
      caseSensitive: false,
    ).firstMatch(taskTitle);
    if (minuteMatch != null) {
      final minutes = int.tryParse(minuteMatch.group(1) ?? '');
      if (minutes != null && minutes > 0) {
        return Duration(minutes: minutes);
      }
    }

    final hourMatch = RegExp(
      r'(\d+)\s*(saat|hour|hours)',
      caseSensitive: false,
    ).firstMatch(taskTitle);
    if (hourMatch != null) {
      final hours = int.tryParse(hourMatch.group(1) ?? '');
      if (hours != null && hours > 0) {
        return Duration(hours: hours);
      }
    }

    return const Duration(minutes: 30);
  }

  static String _matchKey(String canonicalTitle, DateTime scheduledAt) =>
      '$canonicalTitle@${scheduledAt.toIso8601String()}';

  /// Derived from scheduledAt *and* canonicalTitle — scheduledAt alone
  /// used to be the whole id (`ta_<microsecondsSinceEpoch>`), so a re-plan
  /// that happened to land a *different* task type on the exact same
  /// scheduled minute as an already-running task (two DateTime values
  /// built from identical y/m/d/h/min arguments are bit-for-bit identical
  /// down to the microsecond, so this is a real, not just theoretical,
  /// collision) generated the same id for what [_matchKey] correctly
  /// treats as two distinct slots. saveTaskAssignment's
  /// `ConflictAlgorithm.replace` would then silently overwrite the running
  /// task's entire state (attemptCount, postponeCount, barrierStartedAt,
  /// ...) back to freshly-planned. Including the title makes this id
  /// collide under exactly the same condition [_matchKey] already
  /// considers a duplicate, and no other.
  static String _generateId(AdaptiveTaskPlanItem item) =>
      'ta_${item.scheduledAt.microsecondsSinceEpoch}_${item.taskTitle.hashCode}';

  static String _planDateKey(DateTime day) {
    final month = day.month.toString().padLeft(2, '0');
    final dayOfMonth = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$dayOfMonth';
  }

  /// How late a planned task may be and still be worth firing — past this
  /// the real-world window it was aimed at is gone, so it's closed out as
  /// missed instead of delivered late. Duplicated from home_page.dart's own
  /// `_overdueTaskGrace` (same value, same reasoning) rather than shared,
  /// since the background isolate this also runs from cannot depend on
  /// anything that imports Flutter widgets.
  static const Duration _overdueTaskGrace = Duration(minutes: 15);

  /// Builds today's adaptive plan and arms a native alarm for every item not
  /// yet notified — the same work `home_page.dart`'s `_notifyNewTasksInternal`
  /// does on every app open/resume, pulled out here so the midnight
  /// background alarm (`DailyPlanRefreshService`) can do the identical thing
  /// without a Flutter engine or BuildContext.
  ///
  /// Returns the canonicalTitle of any task this call closed out as missed
  /// (there is at most one meaningfully "current" one — home_page.dart only
  /// ever surfaces the last), so a foreground caller can still update its
  /// own UI state; callers that don't need that (the background isolate)
  /// simply ignore the return value.
  Future<String?> scheduleTodaysTaskNotifications({
    bool allowBeforeWakeForBackground = false,
  }) async {
    await syncDeliveryDeferralsFromNative();
    await enforceDeliveryQueueLimit();
    await syncPendingDeliveryExpirationsFromNative();

    final registrationCompleted = await _storage
        .loadInitialRegistrationCompleted();
    if (!registrationCompleted) {
      return null;
    }

    final observationStartedAt = await _storage
        .ensureAdaptiveObservationStartedAt();
    final wakeRaw = await _storage.loadSetting('wake_time') ?? '07:00';
    final sleepRaw = await _storage.loadSleepTime() ?? '21:00';
    final parts = sleepRaw.split(':');
    final sleepHour = int.tryParse(parts.first) ?? 21;
    final sleepMinute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final now = DateTime.now();
    final wakeParts = wakeRaw.split(':');
    final wakeHour = int.tryParse(wakeParts.first) ?? 7;
    final wakeMinute =
        int.tryParse(wakeParts.length > 1 ? wakeParts[1] : '0') ?? 0;
    final wakeAt = DateTime(now.year, now.month, now.day, wakeHour, wakeMinute);
    final planningNow = allowBeforeWakeForBackground && now.isBefore(wakeAt)
        ? wakeAt
        : now;

    var sleepAt = DateTime(
      planningNow.year,
      planningNow.month,
      planningNow.day,
      sleepHour,
      sleepMinute,
    );
    if (!sleepAt.isAfter(planningNow)) {
      sleepAt = sleepAt.add(const Duration(days: 1));
    }

    AdaptiveTaskPlan? adaptivePlan;
    final planningEligible = _storage.isAdaptivePlanningEligible(
      now: planningNow,
      observationStartedAt: observationStartedAt,
      wakeTime: wakeRaw,
    );
    if (planningEligible) {
      final behavior = await _storage.loadBehaviorDashboard();
      adaptivePlan = await _storage.buildAdaptiveNoSmokePlan(
        now: planningNow,
        sleepAt: sleepAt,
        riskyHours: behavior.riskyHours,
      );
    }
    final sleepRoutinePlanItem = buildSleepRoutinePlanItem(sleepAt: sleepAt);
    final planItems = [...?adaptivePlan?.items, sleepRoutinePlanItem];
    if (planItems.isEmpty) {
      return null;
    }

    final planDate = DateTime(now.year, now.month, now.day);
    await planDailyTasks(planDate: planDate, items: planItems);

    final notifiedToday = await _storage.loadNotifiedTaskTitlesToday();
    final taskStates = await _storage.loadTaskAssignmentsForDay(planDate);
    final stateByTitle = <String, String>{
      for (final task in taskStates) task.canonicalTitle: task.state,
    };

    String? missedTaskTitle;
    for (final item in planItems) {
      final task = item.taskTitle;
      if (notifiedToday.contains(task)) {
        continue;
      }
      if ((stateByTitle[task] ?? 'new') != 'new') {
        continue;
      }

      var delay = item.scheduledAt.difference(DateTime.now());
      if (delay <= -_overdueTaskGrace) {
        await _storage.recordAdaptiveTaskOutcome(
          taskTitle: task,
          outcome: AdaptiveTaskOutcome.missed,
          plannedDurationMinutes: item.durationMinutes,
          scheduledAt: item.scheduledAt,
        );
        await _storage.saveMissedTaskTitle(task);
        missedTaskTitle = task;
        await _storage.markTaskTitleNotifiedToday(task);
        continue;
      }
      if (delay.inSeconds <= 0) {
        delay = const Duration(minutes: 1);
      }

      try {
        await NotificationService.scheduleFirstTaskTriggerNotification(
          taskDescription: task,
          delay: delay,
        );
      } catch (_) {
        // One task's native-side scheduling failure must not take every
        // task after it in this loop down with it — see the matching catch
        // in home_page.dart's own copy of this loop for the full reasoning.
        continue;
      }
      await _storage.markTaskTitleNotifiedToday(task);
    }
    return missedTaskTitle;
  }
}
