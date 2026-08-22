import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_texts.dart';
import '../core/app_theme.dart';
import '../core/mentor_command_codes.dart';
import '../models/adaptive_task_models.dart';
import '../models/task_assignment.dart';
import '../models/mentor_message.dart';
import '../models/reduction_progress.dart';
import '../models/survey_record.dart';
import '../models/user_profile_snapshot.dart';
import '../pages/achievements_page.dart';
import '../pages/ai_chat_page.dart';
import '../pages/breath_analysis_page.dart';
import '../pages/breath_test_page.dart';
import '../pages/cough_test_page.dart';
import '../pages/craving_sos_page.dart';
import '../pages/smoked_log_consent_page.dart';
import '../pages/health_metrics_page.dart';
import '../pages/mandatory_task_page.dart';
import '../pages/notifications_page.dart';
import '../pages/personal_progress_page.dart';
import '../pages/protocol_violations_page.dart';
import '../pages/reports_page.dart';
import '../pages/self_challenge_page.dart';
import '../pages/settings_page.dart';
import '../pages/sleep_routine_page.dart';
import '../pages/survey_history_page.dart';
import '../pages/weekly_survey_page.dart';
import '../services/android_watchdog_service.dart';
import '../services/behavior_engine.dart';
import '../services/device_compatibility_service.dart';
import '../services/device_permission_service.dart';
import '../services/location_intelligence_service.dart';
import '../services/step_tracking_service.dart';
import '../services/notification_service.dart';
import '../services/protocol_violation_service.dart';
import '../services/smoked_log_button_service.dart';
import '../services/snoring_detection_service.dart';
import '../services/storage_service.dart';
import '../services/cloud_backup_service.dart';
import '../services/firestore_sync_service.dart';
import '../services/google_auth_service.dart';
import '../services/feature_access.dart';
import '../services/task_assignment_service.dart';
import '../widgets/background_reliability_prompt.dart';
import '../widgets/missing_permission_reminder_prompt.dart';
import '../widgets/no_smoke_logo.dart';
import '../widgets/premium_upsell_dialog.dart';
import '../widgets/quick_action_menu.dart';
import '../widgets/share_app_sheet.dart';

class HomePage extends StatefulWidget {
  final String name;
  final int riskScore;
  final String riskLevel;
  final bool autoCompleteRegistrationOnLoad;
  @visibleForTesting
  final bool mentorCardTestMode;

  const HomePage({
    super.key,
    required this.name,
    required this.riskScore,
    required this.riskLevel,
    this.autoCompleteRegistrationOnLoad = false,
    this.mentorCardTestMode = false,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final StorageService _storageService = StorageService();
  final BehaviorEngine _behaviorEngine = BehaviorEngine();
  final StepTrackingService _stepTrackingService = StepTrackingService();
  final ProtocolViolationService _protocolViolationService =
      ProtocolViolationService();
  final Map<String, String> _taskStates = {};
  final Set<String> _notifiedTaskTitles = <String>{};
  MentorMessage? _latestMentorMessage;
  int _snoringSummaryCount = 0;
  String? _snoringSummaryWorstSeverity;
  StreamSubscription<Map<String, String>>? _taskActionSubscription;
  StreamSubscription<void>? _mandatoryTaskRequestSubscription;
  Timer? _mandatoryGateCallRetryTimer;
  Timer? _mandatoryPostponeRetryTimer;
  int _mandatoryTaskPostponeCount = 0;
  List<Map<String, dynamic>> _pendingFollowUps = const [];
  bool _mandatoryTaskShown = false;
  bool _weeklySurveyMandatoryShown = false;
  bool _registrationCompleted = false;
  bool _isCompletingRegistration = false;
  String _lastSurveyDateText = '...';
  String _lastBreathText = '...';
  String _dailyBreathStatus = '...';
  int _latestExhaleSeconds = 0;
  int _latestInhaleSeconds = 0;
  String _breathTrendText = '...';
  String _weeklyImprovementText = '...';
  String _monthlyImprovementText = '...';
  String _breathPreviousReportText = '...';
  String _breathAverageReportText = '...';
  String _progressSummaryText = '...';
  String _predictedRiskWindow = '...';
  String _predictedTrigger = '...';
  int _predictionConfidence = 0;
  int _adaptiveRiskScore = 0;
  int _weeklyRiskTarget = 0;
  int _planCurrentDay = 1;
  int _planTargetDays = 180;
  int _planDaysRemaining = 179;
  String _planCadenceLevel = 'one_day';
  List<String> _riskyTriggers = const [];
  List<String> _riskyHours = const [];
  List<String> _todaysTasks = const [];
  List<AdaptiveTaskPlanItem> _adaptivePlanItems = const [];
  List<String> _coachCommands = const [];
  int _weeklySurveyRiskScore = 40;
  String _weeklySurveyRiskLevel = 'medium';
  List<String> _riskExplanation = const [];
  String _consecutiveSmokingLatestText = '...';
  String _consecutiveSmokingPreviousText = '...';
  String _consecutiveSmokingTrendText = '...';
  String _consecutiveSmokingStatusText = '...';
  int _successfulTaskCount = 0;
  int _failedTaskCount = 0;
  int _recentSuccessCount = 0;
  int _recentFailureCount = 0;
  int _plannedTaskCountToday = 0;
  int _completedTaskCountToday = 0;
  int _failedTaskCountToday = 0;
  String _nextTaskNotificationText = '...';
  String _notificationContextReasonText = '...';
  int _lastRespiratoryBurden = 25;
  String _lastRespiratoryState = 'stable';
  double _weeklyAverage = 0;
  double _monthlyAverage = 0;
  double _dailyAverage = 0;
  ReductionProgress? _reductionProgress;

  /// A task the overdue-grace branch in [_notifyNewTasks] closed out as
  /// `missed` without ever showing it — kept here so the home screen can
  /// still offer it instead of the user just losing it silently. Cleared on
  /// Start (task begins normally) or Skip (dismissed for good); null once
  /// there is nothing to offer.
  String? _missedTaskTitle;
  Future<void>? _notifyNewTasksInFlight;

  /// Today's tasks that never reached the user at all (overdue-grace
  /// closures + native delivery-gate expirations) — shown as a single
  /// informational line, never counted as the user's own failure.
  int _undeliveredTaskCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _taskActionSubscription = NotificationService.taskActionStream.listen(
      _handleTaskNotificationAction,
    );
    // A task-start notification body tap — see NotificationService's
    // mandatoryTaskRequestController for why this goes through the same
    // path as the app's own resume/foreground check instead of a second,
    // independent push.
    _mandatoryTaskRequestSubscription =
        NotificationService.mandatoryTaskRequestStream.listen((_) {
          unawaited(_presentMandatoryTaskIfNeeded(isRetry: true));
        });
    if (widget.mentorCardTestMode) {
      // Widget tests need a deterministic mentor card, not the production
      // startup graph or SQLite timing. The message still uses canonical
      // codes, so the real localization/rendering path remains exercised.
      _latestMentorMessage = MentorMessage(
        id: 'mentor_widget_test',
        createdAt: DateTime(2000, 1, 1),
        type: 'daily',
        text: MentorMessageCodes.dailySupportive,
        tone: 'supportive',
        quickReplies: const [
          MentorMessageCodes.quickReplyOk,
          MentorMessageCodes.quickReplyStruggling,
          MentorMessageCodes.quickReplyNoTalk,
        ],
        read: false,
      );
      return;
    }
    _loadHomeMetrics();
    unawaited(LocationIntelligenceService().sampleCurrentLocationIfDue());
    unawaited(_stepTrackingService.sampleCurrentStepsIfDue());
    unawaited(_stepTrackingService.ensureDailyProbeScheduled());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_handlePendingQuickLogRoute());
      unawaited(_handlePendingShortcutAction());
      unawaited(_offerQuickLogButtonOnce());
    });
  }

  /// Opens whatever the floating button's menu asked for while the app was
  /// closed.
  ///
  /// The menu runs in a native overlay with no Flutter engine behind it, so
  /// choosing "SOS" there can only leave a note and start the activity — the
  /// same queue-and-drain shape every other native→Dart path here uses.
  /// Without this the user picked SOS mid-craving and landed on the
  /// dashboard.
  Future<void> _handlePendingQuickLogRoute() async {
    final route = await SmokedLogButtonService().drainPendingRoute();
    if (!mounted || route == null) return;

    if (route == SmokedLogButtonService.routeSos) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CravingSosPage()));
      return;
    }

    if (route == SmokedLogButtonService.routeSmokedTrigger) {
      final events = await _storageService.loadSmokingEventsWithoutTrigger();
      if (!mounted || events.isEmpty) return;
      await _offerSmokingTriggerPrompt(events.last.id);
      if (mounted) await _loadHomeMetrics();
    }
  }

  /// Opens whatever the launcher icon's long-press shortcut menu asked for
  /// while the app was closed (see shortcuts.xml / MainActivity
  /// .ShortcutStore) — the same native-overlay-with-no-Flutter-engine shape
  /// as [_handlePendingQuickLogRoute]. 'open_app' needs no branch: Android
  /// already did the only thing that shortcut promises (open the app)
  /// before this ever runs.
  Future<void> _handlePendingShortcutAction() async {
    final action = await AndroidWatchdogService.consumePendingShortcutAction();
    if (!mounted || action == null) return;

    switch (action) {
      case 'smoked_now':
        final eventId = await _storageService.logSmokingNow();
        if (!mounted) return;
        await _offerSmokingTriggerPrompt(eventId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('quickActionSmokedNowConfirmed'))),
        );
        if (mounted) await _loadHomeMetrics();
      case 'craving':
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CravingSosPage()));
      case 'self_challenge':
        final minutes = await showSelfChallengeDurationMenu(context);
        if (!mounted || minutes == null) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SelfChallengePage(durationMinutes: minutes),
          ),
        );
    }
  }

  /// Offers the floating "I smoked" button to someone who was already set up
  /// before it existed.
  ///
  /// Setup offers it now, but that flow only runs once and never again for
  /// an existing install — so everyone who had the app before the button
  /// shipped would only ever find it by scrolling through settings. It is
  /// the app's only source of ground truth about when the user actually
  /// smokes, which is what the barrier length and the risky-hour ranking are
  /// both computed from, so leaving it undiscovered costs the programme its
  /// aim.
  ///
  /// Asked once. Declining is remembered and nothing asks again.
  Future<void> _offerQuickLogButtonOnce() async {
    if (!mounted) return;
    await offerSmokedLogButton(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncPendingQuickLogOnResume());
      // main()'s own call to this only ever covers a genuine cold start —
      // but a notification tap while the engine is already alive can also
      // relaunch MainActivity as a fresh onCreate without main() running
      // again (proven via logcat: ActivityTaskManager starts a new task off
      // the tap's SELECT_NOTIFICATION intent, yet no Flutter-side handler
      // ever fires). Re-checking here on every resume catches that case:
      // if the plugin has launch details queued from this tap, it's the
      // same launch-details codepath main() uses, just run again.
      NotificationService.handleColdStartIfLaunchedFromNotification();
    }
  }

  Future<void> _syncPendingQuickLogOnResume() async {
    await NotificationService.syncSmokedLogEventsFromNative();
    await _handlePendingQuickLogRoute();
    await _handlePendingShortcutAction();
    if (mounted) await _loadHomeMetrics();
    // A resume can follow a native quick-log action or an offline period.
    // Upload the complete local snapshot so the latest progress is not left
    // only on this device until the next cold start.
    unawaited(FirestoreSyncService.syncLocalDatabaseBackup(_storageService));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _taskActionSubscription?.cancel();
    _mandatoryTaskRequestSubscription?.cancel();
    _mandatoryGateCallRetryTimer?.cancel();
    _mandatoryPostponeRetryTimer?.cancel();
    super.dispose();
  }

  /// Loads whatever `task_followups` rows are outstanding, for the pending-
  /// follow-up count shown on the today-task card. Nothing currently writes
  /// to this table (the duration-barrier flow that used to has been folded
  /// into the ADAPTIVE_NO_SMOKE/task_assignments path), so this reliably
  /// returns empty today — kept as a read because a future producer would
  /// need no HomePage change to start showing up here.
  Future<void> _restorePendingFollowUps() async {
    final pending = await _storageService.loadPendingTaskFollowUps();
    if (!mounted) {
      return;
    }
    setState(() {
      _pendingFollowUps = pending;
    });
  }

  String _calculateImprovementLabel(double current, double baseline) =>
      _behaviorEngine.calculateImprovementLabel(current, baseline);

  String _translateTrend(String trendKey) {
    if (trendKey == 'trendImproving') {
      return context.t('trendImproving');
    }
    if (trendKey == 'trendDeclining') {
      return context.t('trendDeclining');
    }
    if (trendKey == 'trendStable') {
      return context.t('trendStable');
    }
    return trendKey;
  }

  String _localizeCanonicalToken(String value) {
    return AppTexts.localizeCanonicalText(context, value);
  }

  String _localizeConsecutiveLabel(String value) {
    final parts = value.split(' - ');
    if (parts.length == 2) {
      return '${_localizeCanonicalToken(parts[0])} - ${_localizeCanonicalToken(parts[1])}';
    }
    return _localizeCanonicalToken(value);
  }

  String _localizeTaskText(String task) {
    return AppTexts.localizeCanonicalText(context, task);
  }

  /// The set [TaskAssignmentService.handleTaskAction] now owns. Anything
  /// outside this set is a legacy follow-up action tied to `task_follow_ups`
  /// rather than `task_assignments`, and keeps running its own older path
  /// below — unchanged from before this method delegated the rest.
  static const Set<String> _taskAssignmentActionIds = {
    TaskActionId.done,
    TaskActionId.notNow,
    TaskActionId.postpone5,
    TaskActionId.postpone10,
    TaskActionId.postpone15,
    TaskActionId.decline,
    TaskActionId.sos,
    TaskActionId.confirmSmokedYes,
    TaskActionId.confirmSmokedNo,
  };

  Future<void> _handleTaskNotificationAction(Map<String, String> event) async {
    final taskTitle = event['taskTitle']?.trim() ?? '';
    final canonicalTitle = event['canonicalTitle']?.trim().isNotEmpty == true
        ? event['canonicalTitle']!.trim()
        : taskTitle;
    final actionId = event['actionId']?.trim() ?? '';
    if (taskTitle.isEmpty || canonicalTitle.isEmpty || actionId.isEmpty) {
      return;
    }

    if (_taskAssignmentActionIds.contains(actionId)) {
      // Read before handleTaskAction transitions the row terminal, so the
      // barrier's own planned length is still known for the win message
      // below — the row itself becomes unreadable-as-"just succeeded" the
      // moment it's transitioned.
      final plannedMinutes = actionId == TaskActionId.confirmSmokedNo
          ? MentorCommandCodes.durationBarrierMinutes(canonicalTitle)
          : null;
      // The notification payload carries localized display text and the
      // canonical ADAPTIVE_NO_SMOKE:<n> code separately. Use the code for
      // persistence and the display text only for the UI.
      final followUp = await TaskAssignmentService(_storageService)
          .handleTaskAction(
            canonicalTitle: canonicalTitle,
            taskTitle: taskTitle,
            actionId: actionId,
          );
      if (!mounted) {
        return;
      }
      if (actionId == TaskActionId.confirmSmokedNo && plannedMinutes != null) {
        unawaited(_showBarrierWonFeedback(plannedMinutes));
      }
      if (actionId == TaskActionId.confirmSmokedYes) {
        unawaited(_offerFailureTriggerPrompt());
      }
      if (followUp == TaskActionFollowUp.openSosPage) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CravingSosPage(taskCanonicalTitle: canonicalTitle),
          ),
        );
      } else if (followUp == TaskActionFollowUp.openSleepRoutinePage) {
        final packsPerDay = await _resolveLatestPacksPerDay();
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SleepRoutinePage(
              canonicalTitle: canonicalTitle,
              name: widget.name,
              packsPerDay: packsPerDay,
            ),
          ),
        );
      }
      setState(() {
        _taskStates[taskTitle] = _uiStateFor(actionId);
      });
      await _loadHomeMetrics();
      return;
    }
  }

  /// The concrete payoff for winning a barrier: how long this one was, plus
  /// the running total for the month — stated in numbers rather than left
  /// implicit in a streak count, since getting through a craving without
  /// smoking is the strongest evidence the programme has that it's working.
  Future<void> _showBarrierWonFeedback(int plannedMinutes) async {
    final monthlyMinutes = await _storageService.monthlySmokeFreeMinutes();
    if (!mounted) return;
    final monthlyHours = (monthlyMinutes / 60).round();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context
              .t('barrierWonFeedback')
              .replaceAll('{minutes}', '$plannedMinutes')
              .replaceAll('{hours}', '$monthlyHours'),
        ),
      ),
    );
  }

  Future<void> _offerSmokingTriggerPrompt(String eventId) async {
    if (!mounted) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(dialogContext.t('failureTriggerPromptTitle')),
        children: [
          for (final (reasonKey, labelKey) in const [
            ('Stres', 'failureTriggerStress'),
            ('Kahve', 'failureTriggerCoffee'),
            ('Yemek', 'failureTriggerMeal'),
            ('Alkol', 'failureTriggerAlcohol'),
            ('Telefon', 'failureTriggerPhone'),
            ('Arac', 'failureTriggerDriving'),
            ('Is Molasi', 'failureTriggerWorkBreak'),
            ('Sosyal Ortam', 'failureTriggerSocial'),
            ('Can Sikintisi', 'failureTriggerBoredom'),
            ('Aliskanlik', 'failureTriggerHabit'),
            ('no_specific_reason', 'failureTriggerNoReason'),
            ('unknown', 'failureTriggerUnknown'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(reasonKey),
              child: Text(dialogContext.t(labelKey)),
            ),
        ],
      ),
    );
    await _storageService.updateSmokingEventTrigger(
      id: eventId,
      trigger: reason ?? 'unknown',
    );
  }

  /// A single-tap, skippable "what happened?" after a barrier failure. The
  /// answer isn't graded or reacted to — it's a data point for the risky-
  /// hour/trigger profile (see StorageService.saveFailureTrigger), so a
  /// failure that's explained is worth as much to that profile as one
  /// reported on next week's survey. Optional on purpose: forcing an answer
  /// here would turn an already-hard moment into one more chore.
  Future<void> _offerFailureTriggerPrompt() async {
    if (!mounted) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(dialogContext.t('failureTriggerPromptTitle')),
        children: [
          for (final (reasonKey, labelKey) in const [
            ('Stres', 'failureTriggerStress'),
            ('Kahve', 'failureTriggerCoffee'),
            ('Yemek', 'failureTriggerMeal'),
            ('Alkol', 'failureTriggerAlcohol'),
            ('Telefon', 'failureTriggerPhone'),
            ('Arac', 'failureTriggerDriving'),
            ('Is Molasi', 'failureTriggerWorkBreak'),
            ('Sosyal Ortam', 'failureTriggerSocial'),
            ('Can Sikintisi', 'failureTriggerBoredom'),
            ('Aliskanlik', 'failureTriggerHabit'),
            ('no_specific_reason', 'failureTriggerNoReason'),
            ('unknown', 'failureTriggerUnknown'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(reasonKey),
              child: Text(dialogContext.t(labelKey)),
            ),
        ],
      ),
    );
    if (reason == null) {
      return;
    }
    await _storageService.saveFailureTrigger(reason);
  }

  /// The in-memory `_taskStates` label a UI badge reads, for an action id
  /// [TaskAssignmentService.handleTaskAction] already applied to storage.
  /// Purely cosmetic — the real state lives in `task_assignments` now.
  static String _uiStateFor(String actionId) {
    switch (actionId) {
      case TaskActionId.done:
        return 'deferred';
      case TaskActionId.decline:
        return 'failed';
      case TaskActionId.confirmSmokedYes:
        return 'failed';
      case TaskActionId.confirmSmokedNo:
        return 'completed';
      default:
        return 'deferred';
    }
  }

  /// Pushes the current snapshot to the home-screen widget (see
  /// android/.../NoSmokeWidgetProvider.kt, which only ever reads this data
  /// back — it never talks to the database directly) and asks Android to
  /// redraw it. Safe to call every time metrics reload since HomeWidget's
  /// underlying SharedPreferences write is cheap and idempotent.
  Future<void> _updateHomeScreenWidget() async {
    if (!mounted) {
      return;
    }
    final streakLabel = context.t('reductionStreakLabel');
    final riskLabel = '${context.t('riskLevel')}: $_adaptiveRiskScore/100';
    try {
      await HomeWidget.saveWidgetData<int>(
        'reductionStreakDays',
        _reductionProgress?.targetStreakDays ?? 0,
      );
      await HomeWidget.saveWidgetData<String>(
        'reductionStreakLabel',
        streakLabel,
      );
      await HomeWidget.saveWidgetData<String>('breathScoreLabel', riskLabel);
      await HomeWidget.updateWidget(
        androidName: 'NoSmokeWidgetProvider',
        qualifiedAndroidName: 'com.nikotinaway.app.NoSmokeWidgetProvider',
      );
    } catch (_) {
      // Best-effort only — the widget is a convenience surface, never a
      // dependency for the rest of the app to keep working.
    }
  }

  Future<void>? _loadHomeMetricsInFlight;

  /// Shares one in-flight load across overlapping callers instead of
  /// starting a second, independent one — same shape and same reason as
  /// [_notifyNewTasks]'s own [_notifyNewTasksInFlight] guard.
  ///
  /// [_loadHomeMetricsInternal] calls StorageService.buildAdaptiveNoSmokePlan
  /// partway through, whose own read-evolve-cache-write is not itself
  /// guarded against concurrent runs (its dependency chain isn't
  /// transaction-executor-aware, so it can't reuse
  /// loadCurrentBarrierMinutes's own in-flight-future fix directly) and
  /// whose plan generation genuinely jitters via Random — two concurrent
  /// runs produce two different plans, not just two agreeing ones. Two
  /// real call sites can overlap on cold start: initState fires this
  /// unawaited, and the very next addPostFrameCallback can fire
  /// _handlePendingQuickLogRoute/_handlePendingShortcutAction, either of
  /// which calls this again once its own drain resolves to a real pending
  /// action — well before the first, much longer call has finished. Without
  /// this guard, whichever call's plan write lands last silently wins,
  /// while the other caller's _adaptivePlanItems/_todaysTasks in memory
  /// reflect the plan that lost the race.
  Future<void> _loadHomeMetrics() {
    final inFlight = _loadHomeMetricsInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _loadHomeMetricsInternal();
    _loadHomeMetricsInFlight = future;
    return future.whenComplete(() {
      if (identical(_loadHomeMetricsInFlight, future)) {
        _loadHomeMetricsInFlight = null;
      }
    });
  }

  Future<void> _loadHomeMetricsInternal() async {
    // A barrier the user never answered either confirmation prompt for —
    // closed out neutrally rather than left open forever or scored as a
    // failure. Runs before everything else so undeliveredTaskCount and the
    // task-state map below already reflect it.
    final closedStaleBarriers = await _storageService
        .closeStaleAcceptedBarriers(
          deadline: NotificationService.barrierResolutionDeadline,
        );
    for (final task in closedStaleBarriers) {
      unawaited(
        NotificationService.cancelBarrierResolutionReminder(
          task.canonicalTitle,
        ),
      );
    }

    // Same idea for an SOS breathing session the user opened and never
    // came back to resume — it has no reminder notification to cancel,
    // just a state that would otherwise sit open forever.
    await _storageService.closeStaleAbandonedSosSessions(
      deadline: NotificationService.barrierResolutionDeadline,
    );

    // Was `now - quitDate`, which counted days the user had smoked on. The
    // reduction figures are derived from logged cigarettes and answered
    // tasks instead, so a day only counts when something actually happened.
    final reductionProgress = await _storageService.loadReductionProgress();

    final registrationCompleted = await _storageService
        .loadInitialRegistrationCompleted();
    // Rebuild and arm today's plan before reading assignment counts. This is
    // the foreground recovery path for days when the midnight background
    // callback was delayed, interrupted, or unavailable on an OEM device.
    if (registrationCompleted) {
      try {
        await TaskAssignmentService(_storageService)
            .scheduleTodaysTaskNotifications();
      } catch (error, stackTrace) {
        debugPrint('[HomePage] daily task recovery failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    final notificationContextReason = await _storageService.loadSetting(
      'last_notification_context_reason',
    );
    final lastDate = await _storageService.loadLastSurveyDate();
    final latestBreath = await _storageService.loadLatestBreathRecord();
    final metrics = await _storageService.loadBreathMetrics();
    final breathProgress = await _storageService.loadBreathProgressReport();
    final consecutiveSmokingSummary = await _storageService
        .loadConsecutiveSmokingSummary();
    final taskOutcomeSummary = await _storageService.loadTaskOutcomeSummary();
    final todaysAssignments = await _storageService.loadTaskAssignmentsForDay(
      DateTime.now(),
    );
    final completedTaskCountToday = todaysAssignments
        .where((task) => task.state == TaskLifecycleState.succeeded)
        .length;
    final failedTaskCountToday = todaysAssignments
        .where(
          (task) =>
              task.state == TaskLifecycleState.failedDeclined ||
              task.state == TaskLifecycleState.failedSmoked ||
              task.state == TaskLifecycleState.failedMissed,
        )
        .length;
    final missedTaskTitle = await _storageService.loadMissedTaskTitle();
    final undeliveredTaskCount = await _storageService
        .countTodaysUndeliveredTasks();
    final lastRespiratoryBurdenRaw = await _storageService.loadSetting(
      'last_respiratory_burden',
    );
    final lastRespiratoryStateRaw = await _storageService.loadSetting(
      'last_respiratory_state',
    );
    final behavior = registrationCompleted
        ? await _storageService.loadBehaviorDashboard()
        : await _storageService.loadLatestBehaviorSnapshot();
    AdaptiveTaskPlan? adaptivePlan;
    AdaptiveTaskPlanItem? sleepRoutinePlanItem;
    if (registrationCompleted) {
      final observationStartedAt = await _storageService
          .ensureAdaptiveObservationStartedAt();
      final wakeRaw = await _storageService.loadSetting('wake_time') ?? '07:00';
      final sleepRaw = await _storageService.loadSleepTime() ?? '21:00';
      final parts = sleepRaw.split(':');
      final sleepHour = int.tryParse(parts.first) ?? 21;
      final sleepMinute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      final now = DateTime.now();
      var sleepAt = DateTime(
        now.year,
        now.month,
        now.day,
        sleepHour,
        sleepMinute,
      );
      if (!sleepAt.isAfter(now)) {
        sleepAt = sleepAt.add(const Duration(days: 1));
      }

      // The first 24 hours are observation-only. After that, the first
      // duration-barrier plan is allowed only after the next day's wake time,
      // so the behavior engine has a full baseline and never interrupts a
      // freshly installed user with a generic schedule.
      final planningEligible = _storageService.isAdaptivePlanningEligible(
        now: now,
        observationStartedAt: observationStartedAt,
        wakeTime: wakeRaw,
      );
      if (planningEligible) {
        adaptivePlan = await _storageService.buildAdaptiveNoSmokePlan(
          now: now,
          sleepAt: sleepAt,
          riskyHours: behavior?.riskyHours ?? const <String>[],
        );
      }
      sleepRoutinePlanItem = TaskAssignmentService.buildSleepRoutinePlanItem(
        sleepAt: sleepAt,
      );
    }
    final pendingFollowUps = await _storageService.loadPendingTaskFollowUps();
    final recentTaskEvents = await _storageService.loadRecentAdaptiveTaskEvents(
      limit: 100,
    );
    if (!mounted) return;
    setState(() {
      _reductionProgress = reductionProgress;
      _missedTaskTitle = missedTaskTitle;
      _undeliveredTaskCount = undeliveredTaskCount;
      _registrationCompleted = registrationCompleted;
      _lastSurveyDateText = lastDate == null
          ? 'noRecordYet'
          : '${lastDate.day}/${lastDate.month}/${lastDate.year}';
      _lastBreathText = latestBreath == null
          ? 'noRecordYet'
          : '${latestBreath.completedAt.day}/${latestBreath.completedAt.month}/${latestBreath.completedAt.year} • ${latestBreath.exhaleTestSeconds}${context.t('secShort')} / ${latestBreath.inhaleTestSeconds}${context.t('secShort')}';
      _latestExhaleSeconds = latestBreath?.exhaleTestSeconds ?? 0;
      _latestInhaleSeconds = latestBreath?.inhaleTestSeconds ?? 0;
      final now = DateTime.now();
      final doneToday =
          latestBreath != null &&
          latestBreath.completedAt.year == now.year &&
          latestBreath.completedAt.month == now.month &&
          latestBreath.completedAt.day == now.day;
      _dailyBreathStatus = doneToday
          ? 'breathTestDoneToday'
          : 'breathTestPendingToday';
      _dailyAverage = metrics['dailyAverage'] ?? 0;
      _weeklyAverage = metrics['weeklyAverage'] ?? 0;
      _monthlyAverage = metrics['monthlyAverage'] ?? 0;
      _weeklyImprovementText = _calculateImprovementLabel(
        _weeklyAverage,
        _monthlyAverage,
      );
      _monthlyImprovementText = _calculateImprovementLabel(
        _monthlyAverage,
        _dailyAverage,
      );
      _breathPreviousReportText = _buildBreathDeltaText(
        delta: (breathProgress['deltaFromPrevious'] as num?)?.toDouble() ?? 0,
        hasReference: breathProgress['hasPrevious'] == true,
        comparisonMode: 'previous',
      );
      _breathAverageReportText = _buildBreathDeltaText(
        delta:
            (breathProgress['deltaFromMonthlyAverage'] as num?)?.toDouble() ??
            0,
        hasReference: true,
        comparisonMode: 'average',
      );
      _adaptiveRiskScore = behavior?.riskScore ?? 0;
      _riskyTriggers = behavior?.riskyTriggers ?? const [];
      _riskyHours = behavior?.riskyHours ?? const [];
      _breathTrendText = behavior?.breathTrend ?? 'Stable';
      _progressSummaryText = behavior?.progressSummary ?? 'Stable';
      _adaptivePlanItems = [...?adaptivePlan?.items, ?sleepRoutinePlanItem];
      _todaysTasks = _adaptivePlanItems.isNotEmpty
          ? _adaptivePlanItems.map((item) => item.taskTitle).toList()
          : behavior?.todaysTasks ?? const [];
      _coachCommands = behavior?.coachCommands ?? const [];
      _weeklySurveyRiskScore = behavior?.weeklySurveyRiskScore ?? 40;
      _weeklySurveyRiskLevel = behavior?.weeklySurveyRiskLevel ?? 'medium';
      _riskExplanation = behavior?.riskExplanation ?? const [];
      _predictedRiskWindow = behavior?.predictedRiskWindow ?? '...';
      _predictedTrigger = behavior?.predictedTrigger ?? '...';
      _predictionConfidence = behavior?.predictionConfidence ?? 0;
      _weeklyRiskTarget = behavior?.plan.weeklyRiskTarget ?? 0;
      _planCurrentDay = behavior?.plan.currentDay ?? 1;
      _planTargetDays = behavior?.plan.targetDays ?? 180;
      _planDaysRemaining = behavior?.plan.daysRemaining ?? 179;
      _planCadenceLevel = behavior?.plan.cadenceLevel ?? 'one_day';
      _consecutiveSmokingLatestText =
          consecutiveSmokingSummary['latest'] ?? context.t('noRecordYet');
      _consecutiveSmokingPreviousText =
          consecutiveSmokingSummary['previous'] ?? context.t('noRecordYet');
      _consecutiveSmokingTrendText =
          consecutiveSmokingSummary['trend'] ?? context.t('noRecordYet');
      _consecutiveSmokingStatusText =
          consecutiveSmokingSummary['status'] ?? context.t('noRecordYet');
      _successfulTaskCount = taskOutcomeSummary['successCount'] ?? 0;
      _failedTaskCount = taskOutcomeSummary['failureCount'] ?? 0;
      _recentSuccessCount = taskOutcomeSummary['recentSuccessCount'] ?? 0;
      _recentFailureCount = taskOutcomeSummary['recentFailureCount'] ?? 0;
      _plannedTaskCountToday = todaysAssignments.length;
      _completedTaskCountToday = completedTaskCountToday;
      _failedTaskCountToday = failedTaskCountToday;
      _notificationContextReasonText =
          (notificationContextReason == null ||
              notificationContextReason.trim().isEmpty)
          ? context.t('taskReasonNoPlanned')
          : notificationContextReason;
      _lastRespiratoryBurden =
          int.tryParse(lastRespiratoryBurdenRaw ?? '25')?.clamp(0, 100) ?? 25;
      _lastRespiratoryState = lastRespiratoryStateRaw ?? 'stable';
      // Restore each task's real state from persisted history instead of
      // defaulting everything to 'new' — otherwise a task the user already
      // completed earlier today looks unfamiliar again after any process
      // restart (the in-memory _taskStates map doesn't survive one), which
      // was the direct cause of the mandatory-task screen re-triggering
      // for work that was already done.
      final deferredTitles = pendingFollowUps
          .map((row) => row['taskTitle'] as String)
          .toSet();
      final resolvedToday = <String, String>{};
      for (final event in recentTaskEvents) {
        final respondedAt = event.respondedAt;
        if (respondedAt.year == now.year &&
            respondedAt.month == now.month &&
            respondedAt.day == now.day) {
          resolvedToday[event.taskTitle] = switch (event.outcome) {
            AdaptiveTaskOutcome.success => 'completed',
            AdaptiveTaskOutcome.smoked => 'failed',
            _ => 'deferred',
          };
        }
      }
      for (final task in _todaysTasks) {
        if (_taskStates.containsKey(task)) {
          // Already has a live, in-session state (e.g. just completed) —
          // don't overwrite it with older persisted history.
          continue;
        }
        if (deferredTitles.contains(task)) {
          _taskStates[task] = 'deferred';
        } else if (resolvedToday.containsKey(task)) {
          _taskStates[task] = resolvedToday[task]!;
        } else {
          _taskStates[task] = 'new';
        }
      }
      _pendingFollowUps = pendingFollowUps;
    });

    await _refreshNextTaskNotificationInsight(pendingFollowUps);
    unawaited(_updateHomeScreenWidget());

    if (widget.autoCompleteRegistrationOnLoad &&
        !_registrationCompleted &&
        !_isCompletingRegistration) {
      unawaited(_completeRegistration());
    }

    if (_registrationCompleted) {
      await _ensureWeeklySurveyCadence();
      if (!mounted) {
        return;
      }
      unawaited(_notifyNewTasks());
      unawaited(_scheduleCoachCommandNotificationsIfNeeded());
      await _restorePendingFollowUps();
      if (!mounted) {
        return;
      }
      unawaited(_presentMandatoryTaskIfNeeded());
      unawaited(_storageService.refreshWearableRiskSignal());
      unawaited(_scheduleSedentaryReminderIfNeeded());
      unawaited(FirestoreSyncService.syncLocalDatabaseBackup(_storageService));
      await _ensureMentorMessageCadence();
      await _loadSnoringSummary();
      unawaited(_promptBackgroundReliabilityIfTasksUndelivered());
      unawaited(_promptMissingPermissionIfDue());
    }
  }

  static const String _lastPermissionReminderDateKey =
      'last_permission_reminder_date';

  /// At most one Accept/Postpone/Decline permission dialog per day, and
  /// only ever one permission at a time — [maybePromptMissingPermission]
  /// itself already skips granted/dismissed/snoozed permissions, this just
  /// adds the same once-a-day cap [_promptBackgroundReliabilityIfTasksUndelivered]
  /// uses so returning users aren't asked again every single launch.
  Future<void> _promptMissingPermissionIfDue() async {
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final lastShownKey = await _storageService.loadSetting(
      _lastPermissionReminderDateKey,
    );
    if (lastShownKey == todayKey) {
      return;
    }
    await _storageService.saveSetting(_lastPermissionReminderDateKey, todayKey);
    if (!mounted) {
      return;
    }
    await maybePromptMissingPermission(
      context: context,
      storageService: _storageService,
    );
  }

  // Was 3 — dropped to 1 because the registration-time prompt (see
  // _completeRegistration) is easy to dismiss without reading on a first
  // run, and by the time 3 tasks had silently gone undelivered the user had
  // typically already concluded the app doesn't work. A single undelivered
  // task is itself the signal worth acting on immediately, not a threshold
  // to wait past.
  static const int _undeliveredTaskReliabilityThreshold = 1;
  static const String _lastReliabilityPromptDateKey =
      'last_reliability_prompt_date';

  /// A pile of tasks the user never even saw (today's undelivered count past
  /// [_undeliveredTaskReliabilityThreshold]) is a delivery-reliability
  /// signal, not a sign the user is failing — OEM battery optimization is
  /// the single most common cause. Reuses the existing background-reliability
  /// dialog rather than inventing a second one; that dialog already no-ops
  /// on non-aggressive devices or once the exemption is granted, so this
  /// only adds a once-a-day cap on top so it isn't re-offered every launch.
  Future<void> _promptBackgroundReliabilityIfTasksUndelivered() async {
    if (_undeliveredTaskCount < _undeliveredTaskReliabilityThreshold) {
      return;
    }
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final lastShownKey = await _storageService.loadSetting(
      _lastReliabilityPromptDateKey,
    );
    if (lastShownKey == todayKey) {
      return;
    }
    await _storageService.saveSetting(_lastReliabilityPromptDateKey, todayKey);
    if (!mounted) {
      return;
    }
    await maybePromptBackgroundReliability(
      context: context,
      deviceCompatibilityService: DeviceCompatibilityService(),
    );
  }

  /// Generates today's mentor message once per day (if not already done)
  /// and loads the latest one for [_buildMentorCard] to display.
  Future<void> _ensureMentorMessageCadence() async {
    final latest = await _storageService.loadLatestMentorMessage();
    final now = DateTime.now();
    final needsToday =
        latest == null ||
        latest.type == 'reframed_violation' ||
        latest.createdAt.year != now.year ||
        latest.createdAt.month != now.month ||
        latest.createdAt.day != now.day;

    final message = needsToday
        ? await _storageService.generateDailyMentorMessage(now: now)
        : latest;

    if (!mounted) {
      return;
    }
    setState(() {
      _latestMentorMessage = message;
    });
  }

  /// Mirrors the same last-12-hours window
  /// NotificationService._syncSnoringResultFromNative reads, so the home
  /// card and the morning notification always agree on what "last night"
  /// means. No separate dedup key -- the card is just whatever's true for
  /// today's data, recomputed on every home-metrics load like every other
  /// card on this tab.
  Future<void> _loadSnoringSummary() async {
    final enabled = await SnoringDetectionService().isEnabled();
    if (!enabled) {
      if (mounted) {
        setState(() {
          _snoringSummaryCount = 0;
          _snoringSummaryWorstSeverity = null;
        });
      }
      return;
    }

    // 24h, matching NotificationService._syncSnoringResultFromNative's
    // window — a 12h lookback anchored to "whenever the user opens the app"
    // misses last night once the user checks in more than 12h after waking.
    final since = DateTime.now().subtract(const Duration(hours: 24));
    final probes = await _storageService.loadSnoringProbeEventsBetween(
      start: since,
      end: DateTime.now(),
    );
    final snoreLikelyProbes = probes.where((e) => e.snoreLikely).toList();

    const order = {'none': 0, 'mild': 1, 'moderate': 2, 'severe': 3};
    String? worst;
    var worstRank = -1;
    for (final probe in snoreLikelyProbes) {
      final level = probe.severityLevel;
      if (level == null) {
        continue;
      }
      final rank = order[level] ?? 0;
      if (rank > worstRank) {
        worstRank = rank;
        worst = level;
      }
    }
    // A snore-likely probe with no severity recorded (e.g. a pre-migration
    // row) must never leave the card showing a positive count next to a
    // "none detected" severity line — those two would directly contradict
    // each other on screen. 'mild' is the honest floor: snoreLikely was
    // still true, the only thing actually missing is how bad it was.
    if (worst == null && snoreLikelyProbes.isNotEmpty) {
      worst = 'mild';
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _snoringSummaryCount = snoreLikelyProbes.length;
      _snoringSummaryWorstSeverity = worst;
    });
  }

  Future<void> _replyToMentorMessage(String reply) async {
    final message = _latestMentorMessage;
    if (message == null) {
      return;
    }
    final isStruggling = reply == MentorMessageCodes.quickReplyStruggling;
    final updatedMessage = message.copyWith(
      read: true,
      userReply: reply,
      followUpQuestion: isStruggling
          ? MentorMessageCodes.followUpStrugglingQuestion
          : null,
      followUpQuickReplies: isStruggling
          ? const [
              MentorMessageCodes.quickReplyReduceTasks,
              MentorMessageCodes.quickReplyEaseBarrier,
              MentorMessageCodes.quickReplyJustTalking,
            ]
          : const [],
    );

    // Render the immediate answer before awaiting SQLite. A slow or unavailable
    // local database must not make the mentor card appear unresponsive.
    if (mounted) {
      setState(() => _latestMentorMessage = updatedMessage);
    }

    if (widget.mentorCardTestMode) {
      // The fixture intentionally has no SQLite row. Widget tests verify the
      // immediate UI transition; production persistence is tested separately.
      return;
    }
    await _storageService.replyToMentorMessage(message.id, reply);
    if (isStruggling) {
      await _storageService.attachMentorFollowUpQuestion(message.id);
    }
  }

  Future<void> _replyToMentorFollowUp(String choice) async {
    final message = _latestMentorMessage;
    if (message == null) {
      return;
    }

    // Update the card and show feedback immediately; persistence follows.
    if (mounted) {
      setState(() {
        _latestMentorMessage = message.copyWith(followUpReply: choice);
      });
    }
    String? snackCode;
    if (choice == MentorMessageCodes.quickReplyReduceTasks) {
      snackCode = MentorMessageCodes.followUpAckReduceTasks;
    } else if (choice == MentorMessageCodes.quickReplyEaseBarrier) {
      snackCode = MentorMessageCodes.followUpAckEaseBarrier;
    }
    if (snackCode != null && mounted) {
      final languageCode = Localizations.localeOf(context).languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppTexts.localizeMentorMessage(languageCode, snackCode),
          ),
        ),
      );
    }
    if (widget.mentorCardTestMode) {
      return;
    }
    await _storageService.applyMentorFollowUpChoice(message.id, choice);
  }

  Color _respiratoryBandColor() {
    switch (_lastRespiratoryState) {
      case 'clinical_review_recommended':
        return Colors.red.shade700;
      case 'monitor_closer':
        return Colors.orange.shade700;
      default:
        return Colors.green.shade700;
    }
  }

  String _respiratoryStateLabel() {
    switch (_lastRespiratoryState) {
      case 'clinical_review_recommended':
        return context.t('respClinicalReview');
      case 'monitor_closer':
        return context.t('respMonitorCloser');
      default:
        return context.t('respStable');
    }
  }

  Future<String> _resolveLatestPacksPerDay() async {
    final records = await _storageService.loadSurveyHistory();
    for (final record in records.reversed) {
      if ((record.packsPerDay).trim().isNotEmpty) {
        return record.packsPerDay;
      }
    }
    return '1 paketten az';
  }

  Future<void> _openBreathTestFromMenu() async {
    await guardPremiumFeature(
      context,
      feature: PremiumFeature.breathCoughTests,
      upsellMessageKey: 'premiumUpsellBreathTests',
      onGranted: () => unawaited(_openBreathTestAfterGate()),
    );
  }

  Future<void> _openBreathTestAfterGate() async {
    final packsPerDay = await _resolveLatestPacksPerDay();
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BreathTestPage(
          name: widget.name,
          packsPerDay: packsPerDay,
          navigateToHomeOnComplete: true,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadHomeMetrics();
  }

  Future<void> _openCoughTestFromMenu() async {
    await guardPremiumFeature(
      context,
      feature: PremiumFeature.breathCoughTests,
      upsellMessageKey: 'premiumUpsellBreathTests',
      onGranted: () => unawaited(_openCoughTestAfterGate()),
    );
  }

  Future<void> _openCoughTestAfterGate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CoughTestPage(navigateToHomeOnComplete: true),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadHomeMetrics();
  }

  Future<void> _openWeeklySurveyFromMenu() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeeklySurveyPage(
          navigateToHomeAfterSave: true,
          nameSeed: widget.name,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadHomeMetrics();
  }

  Future<void> _openPersonalProgressScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PersonalProgressPage()),
    );
  }

  Future<void> _openBreathAnalysisScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BreathAnalysisPage()),
    );
  }

  Future<void> _openReports() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReportsPage()),
    );
  }

  Future<void> _ensureWeeklySurveyCadence() async {
    if (!_registrationCompleted || !mounted) {
      return;
    }

    final dueAt = await _storageService.loadWeeklySurveyDueDate();
    if (dueAt != null) {
      await NotificationService.scheduleWeeklySurveyDueReminder(dueAt: dueAt);
    }

    final overdue = await _storageService.isWeeklySurveyOverdue();
    if (!mounted) {
      return;
    }

    if (overdue) {
      if (_weeklySurveyMandatoryShown) {
        return;
      }
      _weeklySurveyMandatoryShown = true;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(context.t('weeklyMandatoryTitle')),
              content: Text(context.t('weeklyMandatoryContent')),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(context.t('weeklyMandatoryGo')),
                ),
              ],
            ),
          );
        },
      );

      if (!mounted) {
        return;
      }

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WeeklySurveyPage(
            navigateToHomeAfterSave: true,
            nameSeed: widget.name,
            isMandatory: true,
          ),
        ),
      );
      return;
    }
    // No separate "would you like to fill it out now?" nudge below this
    // point on purpose: it used to fire once a day regardless of how
    // recently the survey had actually been completed, so it was asking
    // within the very first days after onboarding — before the weekly
    // survey could possibly be due yet. The `overdue` branch above is the
    // only place this gate belongs; it already covers "ask (and, once
    // truly overdue, require) on a later app open."
  }

  int _resolveCoachCommandNotificationLimit() =>
      _behaviorEngine.resolveCoachCommandNotificationLimit(
        recentSuccessCount: _recentSuccessCount,
        recentFailureCount: _recentFailureCount,
        riskScore: _adaptiveRiskScore,
      );

  Future<void> _scheduleCoachCommandNotificationsIfNeeded() async {
    if (!_registrationCompleted || _coachCommands.isEmpty) {
      return;
    }

    final limit = _resolveCoachCommandNotificationLimit();
    if (limit <= 0) {
      return;
    }

    final now = DateTime.now();
    final signature =
        '${now.year}-${now.month}-${now.day}|$_predictedRiskWindow|${_coachCommands.join('|')}';
    final existing = await _storageService.loadSetting(
      'last_coach_command_signature',
    );
    if (existing == signature) {
      return;
    }

    await NotificationService.scheduleCoachCommandNotifications(
      commands: _coachCommands,
      predictedRiskWindow: _predictedRiskWindow,
      maxNotifications: limit,
    );
    await _storageService.saveSetting(
      'last_coach_command_signature',
      signature,
    );
  }

  // Tasks are still meant to prompt the user several times across a day —
  // this only guards against the screen firing again within a short window
  // of its last appearance (e.g. a handful of app relaunches in a row),
  // not against it appearing multiple times per day, which is intended.
  static const Duration _mandatoryGateCooldown = Duration(minutes: 30);
  // How long to wait before retrying the mandatory-gate check after finding
  // the user on a genuine phone call.
  static const Duration _phoneCallRetryDelay = Duration(minutes: 15);
  // The point of this gate is to actually keep the user from smoking during
  // the target window — tapping "Ertele" (postpone) can't just make it go
  // away, so it comes back after a short delay instead of waiting out the
  // full cooldown, for at least this many attempts per day.
  static const Duration _mandatoryPostponeRetryDelay = Duration(minutes: 10);
  static const int _maxMandatoryPostponeRetries = 5;

  Future<void> _presentMandatoryTaskIfNeeded({bool isRetry = false}) async {
    if (!mounted || (!isRetry && _mandatoryTaskShown)) {
      return;
    }

    // A notification-tap signal can arrive before HomePage's own initState
    // load finishes — the Activity has just started (cold or from
    // background) and _registrationCompleted is still the default false
    // while _loadHomeMetrics is still awaiting its DB reads. Without this
    // wait the signal was simply dropped here, with nothing left to retry
    // it: the notification itself is already cancelled by this point, so
    // the task screen never appeared and looked exactly like an unanswered
    // notification. Same 300ms-step retry shape already used below for
    // _mandatoryTaskRequestController.hasListener.
    var readyWaitAttempts = 0;
    while (!_registrationCompleted && readyWaitAttempts < 10) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      readyWaitAttempts++;
      if (!mounted) return;
    }
    if (!_registrationCompleted) {
      return;
    }

    final pendingMandatoryTask =
        await _storageService.loadPendingMandatoryTask();

    if (!isRetry && pendingMandatoryTask == null) {
      final lastShownAt = await _storageService.loadLastMandatoryGateShownAt();
      if (lastShownAt != null &&
          DateTime.now().difference(lastShownAt) < _mandatoryGateCooldown) {
        return;
      }
    }

    // Don't interrupt a genuine phone call with the mandatory-command
    // screen. This is a one-shot check at present-time, not a live
    // listener, so it retries once after the same delay rather than trying
    // to catch the exact moment the call ends.
    if (await DevicePermissionService.isInPhoneCall()) {
      _mandatoryGateCallRetryTimer?.cancel();
      _mandatoryGateCallRetryTimer = Timer(
        _phoneCallRetryDelay,
        () => unawaited(_presentMandatoryTaskIfNeeded()),
      );
      return;
    }

    // Due follow-ups are handled by _presentPendingFollowUpIfNeeded (asks
    // "did it succeed", not "start this task") — only genuinely new tasks
    // reach this gate.
    //
    // A "new" task is not necessarily a due one: the daily plan is built in
    // full the moment registration completes, so its first item can carry a
    // scheduledAt hours in the future. Without checking that against now,
    // finishing the onboarding survey landed the user straight on this
    // fake-call-style screen for a task that was never meant to fire yet.
    final now = DateTime.now();
    String? taskTitle;
    final pendingCanonicalTitle =
        pendingMandatoryTask?['canonicalTitle']?.trim();
    if (pendingCanonicalTitle != null &&
        pendingCanonicalTitle.isNotEmpty &&
        _todaysTasks.contains(pendingCanonicalTitle)) {
      taskTitle = pendingCanonicalTitle;
    }
    if ((taskTitle ?? '').isEmpty) {
      for (final task in _todaysTasks) {
        if ((_taskStates[task] ?? 'new') != 'new') {
          continue;
        }
        final planItem = _adaptivePlanItems
            .where((item) => item.taskTitle == task)
            .firstOrNull;
        if (planItem != null && planItem.scheduledAt.isAfter(now)) {
          continue;
        }
        taskTitle = task;
        break;
      }
    }

    if ((taskTitle ?? '').trim().isEmpty) {
      return;
    }

    _mandatoryTaskShown = true;
    // Consume the durable tap only after the task was found and the app is
    // ready to present it. The in-memory guard prevents a second presentation
    // from the resume signal in the same session.
    if (pendingMandatoryTask != null) {
      await _storageService.clearPendingMandatoryTask();
    }
    // Guarded non-null by the empty-check above.
    await _protocolViolationService.logMandatoryGateShown(
      taskTitle: taskTitle!,
    );

    if (!mounted) {
      return;
    }
    // The notification carries no actions any more, so this page is the only
    // place any of these choices get made — it pops with a TaskActionId, or
    // null if it was somehow dismissed without one (it isn't pop-dismissible,
    // but a hot-reload/route-replace edge case could still surface null).
    final actionId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => MandatoryTaskPage(taskTitle: taskTitle!),
      ),
    );

    // This page can be reached without ever tapping the notification (opened
    // by this method's own resume/foreground check), so unlike the
    // notification-action path there is no watchdogId in hand here — without
    // this, the native "waiting for response" foreground notification stayed
    // up regardless of what the user chose on the page. It used to be
    // acknowledged only inside the "accepted" branch below, so declining
    // left it stuck until the native watchdog's own 15-minute timeout wrote
    // a violation.
    unawaited(
      AndroidWatchdogService.acknowledgeWatchdogByTaskTitle(taskTitle),
    );

    if (actionId == null) {
      if (_mandatoryTaskPostponeCount < _maxMandatoryPostponeRetries) {
        _mandatoryTaskPostponeCount++;
        _mandatoryTaskShown = false;
        _mandatoryPostponeRetryTimer?.cancel();
        _mandatoryPostponeRetryTimer = Timer(
          _mandatoryPostponeRetryDelay,
          () => unawaited(_presentMandatoryTaskIfNeeded(isRetry: true)),
        );
      }
      return;
    }

    _mandatoryTaskPostponeCount = 0;
    final row = await _storageService.loadLatestTaskAssignmentByTitle(
      taskTitle,
    );
    final followUp = await TaskAssignmentService(_storageService)
        .handleTaskAction(
          canonicalTitle: taskTitle,
          taskTitle: taskTitle,
          actionId: actionId,
        );
    if (!mounted) return;
    if (actionId == TaskActionId.done &&
        TaskAssignmentService.isComposite(row?.taskKind ?? '') &&
        followUp == TaskActionFollowUp.openSleepRoutinePage) {
      // The pre-sleep routine has no countdown/follow-up of its own —
      // accepting it on the fake-call screen hands the user straight into
      // SleepRoutinePage, same as the notification-action path.
      final packsPerDay = await _resolveLatestPacksPerDay();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SleepRoutinePage(
            canonicalTitle: taskTitle!,
            name: widget.name,
            packsPerDay: packsPerDay,
          ),
        ),
      );
      if (!mounted) return;
    } else if (followUp == TaskActionFollowUp.openSosPage) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CravingSosPage(taskCanonicalTitle: taskTitle),
        ),
      );
      if (!mounted) return;
    }
    setState(() {
      _taskStates[taskTitle!] = _uiStateFor(actionId);
    });
    await _loadHomeMetrics();
  }

  /// How late a planned task may be and still be worth firing. Past this the
  /// real-world window it was aimed at is gone, so it is closed out as missed
  /// rather than delivered late (see the overdue branch in [_notifyNewTasks]).
  static const Duration _overdueTaskGrace = Duration(minutes: 15);

  Future<void> _notifyNewTasks() {
    final inFlight = _notifyNewTasksInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _notifyNewTasksInternal();
    _notifyNewTasksInFlight = future;
    return future.whenComplete(() {
      if (identical(_notifyNewTasksInFlight, future)) {
        _notifyNewTasksInFlight = null;
      }
    });
  }

  Future<void> _notifyNewTasksInternal() async {
    final taskAssignmentService = TaskAssignmentService(_storageService);
    // Picks up whatever the native gate deferred while the app was closed
    // (TaskTriggerReceiver.kt's DeliveryGateStore) before the queue-limit
    // backstop below runs, so a task deferred and then re-blocked past the
    // limit is counted correctly rather than still sitting in `planned`.
    await taskAssignmentService.syncDeliveryDeferralsFromNative();
    // Backstop for the native delivery-gate queue limit while the app is
    // open — a task stuck in pendingDelivery beyond the queue limit is
    // closed out here even on a day with nothing new to notify.
    await taskAssignmentService.enforceDeliveryQueueLimit();
    // Picks up whatever the native queue limit already closed out while the
    // app was closed (TaskTriggerReceiver.kt's PendingDeliveryQueue).
    await taskAssignmentService.syncPendingDeliveryExpirationsFromNative();

    if (_todaysTasks.isEmpty) {
      return;
    }

    // Persisted, not just in-memory: `_notifiedTaskTitles` alone forgot
    // what had already been notified every time the process restarted
    // (very common — OEM battery killers, normal app-switching), so every
    // reopen re-scheduled a fresh notification for every task still 'new',
    // stacking duplicates on top of whatever was already pending from
    // earlier that day. See StorageService.loadNotifiedTaskTitlesToday.
    final notifiedToday = await _storageService.loadNotifiedTaskTitlesToday();
    _notifiedTaskTitles.addAll(notifiedToday);

    if (_adaptivePlanItems.isNotEmpty) {
      final planDate = DateTime.now();
      await taskAssignmentService.planDailyTasks(
        planDate: planDate,
        items: _adaptivePlanItems,
      );

      DateTime? nextAt;
      for (final item in _adaptivePlanItems) {
        final task = item.taskTitle;
        if (_notifiedTaskTitles.contains(task)) {
          continue;
        }
        if ((_taskStates[task] ?? 'new') != 'new') {
          continue;
        }

        var delay = item.scheduledAt.difference(DateTime.now());
        if (delay <= -_overdueTaskGrace) {
          // The moment this task was tied to has already passed — firing it
          // now would just be catch-up spam with no therapeutic value, and
          // reopening the app after a few hours away would dump every task
          // the user was away for onto them at once. Close it out as missed
          // instead so the learning engine still hears about it.
          await _storageService.recordAdaptiveTaskOutcome(
            taskTitle: task,
            outcome: AdaptiveTaskOutcome.missed,
            plannedDurationMinutes: item.durationMinutes,
            scheduledAt: item.scheduledAt,
          );
          // The learning engine has heard about it, but the user hasn't --
          // remember it so the home screen can still offer to start it
          // instead of it just disappearing.
          await _storageService.saveMissedTaskTitle(task);
          if (mounted) {
            setState(() => _missedTaskTitle = task);
          }
          _notifiedTaskTitles.add(task);
          await _storageService.markTaskTitleNotifiedToday(task);
          continue;
        }
        if (delay.inSeconds <= 0) {
          // Only just missed (still inside the grace window) — worth firing.
          delay = const Duration(minutes: 1);
        }

        try {
          await NotificationService.scheduleFirstTaskTriggerNotification(
            taskDescription: task,
            delay: delay,
          );
        } catch (_) {
          // One task's native-side scheduling failure (e.g. a platform
          // exception starting the watchdog's foreground service) must not
          // silently take every task after it in this loop down with it —
          // that previously left the rest of today's plan without a single
          // notification, with no error ever surfacing anywhere. Skipping
          // _notifiedTaskTitles/markTaskTitleNotifiedToday below means this
          // task is retried on the next call instead of being marked done.
          continue;
        }

        _notifiedTaskTitles.add(task);
        await _storageService.markTaskTitleNotifiedToday(task);
        if (nextAt == null || item.scheduledAt.isBefore(nextAt)) {
          nextAt = item.scheduledAt;
        }
      }

      if (nextAt != null && mounted) {
        setState(() {
          _nextTaskNotificationText = _formatDateTime(nextAt!);
        });
      }
      return;
    }

    // No second scheduler beyond this point.
    //
    // There used to be a fallback here that fired whenever the adaptive plan
    // was empty, spacing tasks as `base + index * gap` measured from the
    // moment the app happened to be open. That is not a time of day — it is
    // an offset from install, so a user who finished setup at nine in the
    // evening had their whole day's tasks stacked into the next hour and a
    // half, one after another. It also produced titles the learning engine
    // cannot score: only `ADAPTIVE_NO_SMOKE:n` is recognised, so nothing
    // those tasks did ever reached the barrier review.
    //
    // The plan is the schedule. When it comes back empty the honest answer
    // is no tasks — either setup isn't finished, or the remaining part of
    // today genuinely has no room left for a barrier-length commitment.
    // Registration still starts the first one on its own.
  }

  static const Duration _sedentaryReminderCooldown = Duration(hours: 3);

  /// Phase 11: a gentle "you've been still for a while" nudge, reusing the
  /// step data already collected for reports (no new sensor/permission).
  /// Gated by waking hours (hour-granularity is enough for this — it's a
  /// wellness suggestion, not a precise scheduler) and a cooldown so it
  /// can fire more than once a day without turning into the same
  /// duplicate-notification problem `_notifyNewTasks` had.
  Future<void> _scheduleSedentaryReminderIfNeeded() async {
    if (!_registrationCompleted) {
      return;
    }

    final now = DateTime.now();
    final sleepRaw = await _storageService.loadSleepTime() ?? '23:00';
    final wakeRaw = await _storageService.loadSetting('wake_time') ?? '07:00';
    final sleepHour = int.tryParse(sleepRaw.split(':').first) ?? 23;
    final wakeHour = int.tryParse(wakeRaw.split(':').first) ?? 7;
    final withinWakingHours = wakeHour <= sleepHour
        ? now.hour >= wakeHour && now.hour < sleepHour
        : now.hour >= wakeHour || now.hour < sleepHour;
    if (!withinWakingHours) {
      return;
    }

    final lastRaw = await _storageService.loadSetting(
      'last_sedentary_reminder_at',
    );
    final last = lastRaw != null ? DateTime.tryParse(lastRaw) : null;
    if (last != null && now.difference(last) < _sedentaryReminderCooldown) {
      return;
    }

    if (!await _storageService.isRecentlySedentary()) {
      return;
    }

    await NotificationService.showSedentaryReminderNotification();
    await _storageService.saveSetting(
      'last_sedentary_reminder_at',
      now.toIso8601String(),
    );
  }

  Future<void> _refreshNextTaskNotificationInsight(
    List<Map<String, dynamic>> pendingFollowUps,
  ) async {
    String label = context.t('taskReasonNoPlanned');

    if (pendingFollowUps.isNotEmpty) {
      final sorted = [...pendingFollowUps]
        ..sort(
          (a, b) => (a['scheduledAt'] as DateTime).compareTo(
            b['scheduledAt'] as DateTime,
          ),
        );
      final nextAt = sorted.first['scheduledAt'] as DateTime;
      label = _formatDateTime(nextAt);
    } else {
      if (_adaptivePlanItems.isNotEmpty) {
        final now = DateTime.now();
        final upcoming = _adaptivePlanItems.where(
          (item) =>
              item.scheduledAt.isAfter(now) &&
              (_taskStates[item.taskTitle] ?? 'new') == 'new' &&
              !_notifiedTaskTitles.contains(item.taskTitle),
        );

        if (upcoming.isNotEmpty) {
          final sorted = [...upcoming]
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
          label = _formatDateTime(sorted.first.scheduledAt);
        }
      }
      // With no plan there is no next task, so there is no time to show.
      // This branch used to compute one from the same `index * gap` offset
      // the retired fallback scheduler used, which meant the card announced
      // a task that nothing was going to deliver.
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _nextTaskNotificationText = label;
    });
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  String _buildBreathDeltaText({
    required double delta,
    required bool hasReference,
    required String comparisonMode,
  }) {
    if (!hasReference) {
      return context.t('breathNoReferenceYet');
    }

    final amount = delta.abs().toStringAsFixed(1);
    if (delta > 0.2) {
      return comparisonMode == 'previous'
          ? '${context.t('breathComparedPreviousImproved')} $amount${context.t('secShort')}'
          : '${context.t('breathComparedAverageImproved')} $amount${context.t('secShort')}';
    }
    if (delta < -0.2) {
      return comparisonMode == 'previous'
          ? '${context.t('breathComparedPreviousDeclined')} $amount${context.t('secShort')}'
          : '${context.t('breathComparedAverageDeclined')} $amount${context.t('secShort')}';
    }
    return comparisonMode == 'previous'
        ? context.t('breathComparedPreviousStable')
        : context.t('breathComparedAverageStable');
  }

  String _localizedRiskLabel() {
    final score = _adaptiveRiskScore == 0
        ? widget.riskScore
        : _adaptiveRiskScore;
    if (score >= 80) {
      return context.t('riskCritical');
    }
    if (score >= 60) {
      return context.t('riskHigh');
    }
    if (score >= 40) {
      return context.t('riskMedium');
    }
    return context.t('riskLow');
  }

  String _localizedWeeklyRiskLevel() {
    return AppTexts.localizeCanonicalText(context, _weeklySurveyRiskLevel);
  }

  void _showRegistrationError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _validateRegistrationInputs() async {
    final records = await _storageService.loadSurveyHistory();
    final hasInitialSurvey = await _storageService.hasCompletedInitialSurvey(
      records: records,
    );
    final hasBreathTest = records.any((record) => record.type == 'breath_test');
    return hasInitialSurvey && hasBreathTest;
  }

  Future<void> _createInitialProfileSnapshot() async {
    final records = await _storageService.loadSurveyHistory();
    final triggerMap = await _storageService.loadTriggerMapByRecordId();
    final contextMap = await _storageService.loadSurveyContextByRecordId();

    SurveyRecord? latestSurvey;
    SurveyRecord? latestBreath;
    for (final record in records.reversed) {
      if (latestSurvey == null &&
          (record.type == 'initial' || record.type == 'weekly')) {
        latestSurvey = record;
      }
      if (latestBreath == null && record.type == 'breath_test') {
        latestBreath = record;
      }
      if (latestSurvey != null && latestBreath != null) {
        break;
      }
    }

    if (latestSurvey == null) {
      throw StateError(
        'Initial/weekly survey record not found while creating profile snapshot.',
      );
    }
    if (latestBreath == null) {
      throw StateError(
        'Breath test record not found while creating profile snapshot.',
      );
    }

    final latestContext = contextMap[latestSurvey.id];
    final healthConditions =
        (latestContext?['healthConditions'] as List<String>?) ??
        const <String>[];
    final triggers = triggerMap[latestSurvey.id] ?? const <String>[];

    await _storageService.saveUserProfileSnapshot(
      UserProfileSnapshot(
        id: 'profile_init_${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
        riskScore: latestSurvey.riskScore,
        packsPerDay: latestSurvey.packsPerDay,
        firstCigaretteRange: 'unknown',
        smokeFreeRange: 'unknown',
        consecutiveSmokingHabit:
            latestSurvey.consecutiveSmokingHabit ?? 'Hayır',
        consecutiveSmokingCount: latestSurvey.consecutiveSmokingCount,
        triggers: triggers,
        healthConditions: healthConditions,
        profession: (latestContext?['profession'] as String?) ?? 'Belirtilmedi',
        sleepTime: (latestContext?['sleepTime'] as String?) ?? '21:00',
        wakeTime: (latestContext?['wakeTime'] as String?) ?? '07:00',
        latestExhaleSeconds: latestBreath.exhaleTestSeconds,
        latestInhaleSeconds: latestBreath.inhaleTestSeconds,
      ),
    );
  }

  Future<void> _offerInitialCloudBackup() async {
    if (!GoogleAuthService.isCloudUser || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    const promptKey = 'initial_cloud_backup_prompt_shown';
    if (prefs.getBool(promptKey) == true || !mounted) return;

    final controller = TextEditingController();
    final passphrase = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('cloudBackupRow')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('cloudBackupPhoneChangeWarning')),
            const SizedBox(height: 12),
            Text(context.t('cloudBackupPassphraseHint')),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.t('cloudBackupPassphraseLabel'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t('no')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(context.t('cloudBackupRow')),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    final trimmed = passphrase?.trim() ?? '';
    if (passphrase == null) {
      await prefs.setBool(promptKey, true);
      return;
    }
    if (trimmed.length < 6 || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('cloudBackupPassphraseTooShort'))),
        );
      }
      return;
    }

    try {
      await CloudBackupService(
        storageService: _storageService,
      ).backup(passphrase: trimmed);
      await prefs.setBool(promptKey, true);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('cloudBackupSuccess'))));
    } catch (error, stackTrace) {
      debugPrint('[HomePage] Initial cloud backup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('cloudBackupFailed'))));
    }
  }

  Future<void> _completeRegistration() async {
    if (_isCompletingRegistration || _registrationCompleted) {
      return;
    }

    setState(() {
      _isCompletingRegistration = true;
    });

    try {
      debugPrint('[CompleteRegistration] Started');
      final isValid = await _validateRegistrationInputs();
      if (!isValid) {
        debugPrint('[CompleteRegistration] Validation failed');
        if (!mounted) return;
        _showRegistrationError(context.t('registrationMissingFields'));
        return;
      }

      try {
        debugPrint(
          '[CompleteRegistration] Running _createInitialProfileSnapshot',
        );
        await _createInitialProfileSnapshot();
      } catch (error, stackTrace) {
        debugPrint('[CompleteRegistration] Profile creation failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        if (!mounted) return;
        _showRegistrationError(context.t('registrationProfileCreationFailed'));
        return;
      }

      debugPrint('[CompleteRegistration] Running loadBehaviorDashboard');
      try {
        await _storageService.loadBehaviorDashboard();
      } catch (error, stackTrace) {
        debugPrint(
          '[CompleteRegistration] loadBehaviorDashboard failed: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
        if (!mounted) return;
        _showRegistrationError(context.t('registrationRiskAnalysisFailed'));
        return;
      }
      if (!mounted) {
        return;
      }
      // No task at the finish line of setup.
      //
      // Registration used to create one and fire it ten minutes later. The
      // user had just spent five screens answering questions; being handed a
      // full-screen command straight afterwards reads as nagging, and it
      // arrives before the barrier has been seeded from those answers, so it
      // is not even the right length. The daily plan schedules the first real
      // task at a time of day that suits the person, which is the whole point
      // of having asked.

      debugPrint('[CompleteRegistration] Saving completion flag');
      try {
        await _storageService.saveInitialRegistrationCompleted(true);
        await _storageService.saveIsProfileCompleted(true);
      } catch (error, stackTrace) {
        debugPrint(
          '[CompleteRegistration] save registration flags failed: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
        if (!mounted) return;
        _showRegistrationError(context.t('registrationFlagSaveFailed'));
        return;
      }
      debugPrint('[CompleteRegistration] Refreshing Home metrics');
      await _loadHomeMetrics();
      await _offerInitialCloudBackup();

      if (!mounted) {
        return;
      }

      // The single moment the user has just committed to being tracked even
      // when they forget to open the app — the whole premise of the coach
      // program. On a known-aggressive OEM, that promise silently breaks
      // the first time the background service gets killed, and until now
      // this prompt only ever surfaced reactively (3 missed tasks in, or by
      // opening a feature that happens to need it) — often long after the
      // user had already concluded the app "doesn't work". Asking once,
      // right here, is the earliest point that context makes sense.
      await maybePromptBackgroundReliability(
        context: context,
        deviceCompatibilityService: DeviceCompatibilityService(),
      );
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('registrationCompleted'))),
      );
      debugPrint('[CompleteRegistration] Completed successfully');
    } catch (error, stackTrace) {
      debugPrint('[CompleteRegistration] Failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showRegistrationError(context.t('completeRegistrationError'));
    } finally {
      if (mounted) {
        setState(() {
          _isCompletingRegistration = false;
        });
      }
    }
  }

  int _selectedTabIndex = 0;

  Widget _buildDailyPulseHeader(BuildContext context) {
    final plannedCount = _plannedTaskCountToday;
    final completedCount = _completedTaskCountToday;
    final failedCount = _failedTaskCountToday;
    final total = plannedCount;
    final ratio = total == 0 ? 0.0 : completedCount / total;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceQuiet,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.t('welcome')}, ${widget.name}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t('home'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.t('taskCountToday'),
                style: const TextStyle(color: AppTheme.inkMuted, fontSize: 12),
              ),
              Text(
                '$completedCount/$total ${context.t('taskUnit')}',
                style: const TextStyle(
                  color: AppTheme.brandAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: ratio.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(AppTheme.ember),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${context.t('successfulTaskCount')}: $completedCount • '
            '${context.t('failedTaskCount')}: $failedCount',
            style: const TextStyle(
              color: AppTheme.inkMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDailyPulseHeader(context),
          const SizedBox(height: 18),
          if (_latestMentorMessage != null) ...[
            _buildMentorCard(context),
            const SizedBox(height: 18),
          ],
          if (_snoringSummaryCount > 0) ...[
            _buildSnoringSummaryCard(context),
            const SizedBox(height: 18),
          ],
          _buildReductionCard(context),
          const SizedBox(height: 18),
          _buildHealthMetricsButton(context),
          const SizedBox(height: 18),
          _buildSummaryStats(context),
          const SizedBox(height: 18),
          _buildBreathTrendCard(),
          if (!_registrationCompleted) ...[
            const SizedBox(height: 18),
            _buildCompleteRegistrationButton(context),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsTab(BuildContext context) {
    return const SettingsPage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.12,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: NoSmokeLogo(
                    size: 300,
                    showLabel: true,
                    showTagline: true,
                    labelColor: AppTheme.brandPrimary,
                  ),
                ),
              ),
            ),
          ),
          IndexedStack(
            index: _selectedTabIndex,
            children: widget.mentorCardTestMode
                ? [_buildHomeTab(context)]
                : [
                    _buildHomeTab(context),
                    _buildTestsTab(context),
                    _buildTrackingTab(context),
                    _buildSettingsTab(context),
                  ],
          ),
        ],
      ),
      bottomNavigationBar: widget.mentorCardTestMode
          ? null
          : NavigationBar(
              selectedIndex: _selectedTabIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedTabIndex = index),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: context.t('home'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.assignment_outlined),
                  selectedIcon: const Icon(Icons.assignment),
                  label: context.t('tabTests'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.insights_outlined),
                  selectedIcon: const Icon(Icons.insights),
                  label: context.t('tabTracking'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: context.t('settingsTitle'),
                ),
              ],
            ),
    );
  }

  Future<void> _shareApp() async {
    // Routes through the same sheet as Settings, Reports and the weekly
    // survey. This used to share a hardcoded Turkish sentence, so a German or
    // Tamil user shared Turkish text — and the store link was missing entirely.
    await showShareAppSheet(context);
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NoSmokeLogo(size: 30),
          const SizedBox(width: 10),
          Text(
            context.t('home'),
            style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.2),
          ),
        ],
      ),
      actions: [
        IconButton(
          key: const ValueKey('share_app_button'),
          tooltip: context.t('shareAppTitle'),
          icon: const Icon(Icons.share_rounded),
          onPressed: _shareApp,
        ),
        // Notifications stay pinned in the app bar so the user can open
        // the full notification history from anywhere on the dashboard.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: IconButton(
            key: const ValueKey('notifications_button'),
            tooltip: context.t('notificationsPageTitle'),
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMentorCard(BuildContext context) {
    final message = _latestMentorMessage!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final toneColor = switch (message.tone) {
      'coach' => AppTheme.brandPrimary,
      'supportive' => Colors.amber,
      _ => Colors.white70,
    };
    final answered = message.userReply != null;
    final statusKey = switch (message.tone) {
      'coach' => 'riskLow',
      'supportive' => 'riskHigh',
      _ => 'riskMedium',
    };
    return Card(
      color: toneColor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: toneColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite, color: toneColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  context.t('mentorCardTitle'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: toneColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: toneColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: toneColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                '${context.t('riskLevel')}: ${context.t(statusKey)}',
                style: TextStyle(
                  color: toneColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppTexts.localizeMentorMessage(languageCode, message.text),
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            if (!answered && message.tone == 'supportive') ...[
              const SizedBox(height: 8),
              Text(
                context.t('mentorFollowupStrugglingQ'),
                style: const TextStyle(
                  color: AppTheme.inkMuted,
                  fontSize: 12,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (message.quickReplies.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildMentorReplyArea(context, message, languageCode, answered),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: () => guardPremiumFeature(
                  context,
                  feature: PremiumFeature.aiMentor,
                  upsellMessageKey: 'premiumUpsellAiMentor',
                  onGranted: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AIChatPage()),
                    );
                  },
                ),
                icon: const Icon(Icons.smart_toy_outlined, size: 18),
                label: Text(context.t('aiMentorButton')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnoringSummaryCard(BuildContext context) {
    final severity = _snoringSummaryWorstSeverity;
    final toneColor = switch (severity) {
      'severe' => Colors.red,
      'moderate' => Colors.orange,
      'mild' => Colors.amber,
      _ => Colors.white70,
    };
    final severityTextKey = switch (severity) {
      'severe' => 'snoringSeveritySevere',
      'moderate' => 'snoringSeverityModerate',
      'mild' => 'snoringSeverityMild',
      _ => 'snoringSeverityNone',
    };

    return Card(
      key: const ValueKey('home_snoring_summary_card'),
      color: toneColor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: toneColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.graphic_eq, color: toneColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.t('sleepIntelligenceTitle'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: toneColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _snoringSummaryCount > 0
                  ? context
                        .t('snoringHomeSummaryCardBodyDetected')
                        .replaceAll('{count}', '$_snoringSummaryCount')
                  : context.t('snoringSeverityNone'),
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            if (_snoringSummaryCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                context.t(severityTextKey),
                style: TextStyle(
                  fontSize: 13,
                  color: toneColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The area below the mentor's message — one of four states depending on
  /// how far the "Zorlanıyorum" branch has progressed:
  /// 1. Not answered yet → the original quick-reply buttons (İyiyim/
  ///    Zorlanıyorum).
  /// 2. Answered "İyiyim" (or answered "Zorlanıyorum" but no follow-up
  ///    question was attached — a defensive fallback) → the static
  ///    "cevabın gönderildi" text, same as before this feature existed.
  /// 3. Answered "Zorlanıyorum", follow-up question attached, not yet
  ///    answered → the follow-up question + its 3 buttons.
  /// 4. Follow-up answered → a final acknowledgement text.
  Widget _buildMentorReplyArea(
    BuildContext context,
    MentorMessage message,
    String languageCode,
    bool answered,
  ) {
    if (!answered) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: message.quickReplies
            .map(
              (reply) => OutlinedButton(
                key: ValueKey('mentor_reply_$reply'),
                onPressed: () => _replyToMentorMessage(reply),
                child: Text(
                  AppTexts.localizeMentorReplyCode(languageCode, reply),
                ),
              ),
            )
            .toList(),
      );
    }

    final isStrugglingWithFollowUp =
        message.userReply == MentorMessageCodes.quickReplyStruggling &&
        message.followUpQuestion != null;

    if (isStrugglingWithFollowUp && message.followUpReply == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key: const ValueKey('mentor_follow_up_question'),
            AppTexts.localizeMentorMessage(
              languageCode,
              message.followUpQuestion!,
            ),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: message.followUpQuickReplies
                .map(
                  (reply) => OutlinedButton(
                    key: ValueKey('mentor_follow_up_reply_$reply'),
                    onPressed: () => _replyToMentorFollowUp(reply),
                    child: Text(
                      AppTexts.localizeMentorReplyCode(languageCode, reply),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      );
    }

    if (isStrugglingWithFollowUp && message.followUpReply != null) {
      final ackCode = switch (message.followUpReply) {
        MentorMessageCodes.quickReplyReduceTasks =>
          MentorMessageCodes.followUpAckReduceTasks,
        MentorMessageCodes.quickReplyEaseBarrier =>
          MentorMessageCodes.followUpAckEaseBarrier,
        _ => MentorMessageCodes.followUpAckJustTalking,
      };
      return Text(
        key: const ValueKey('mentor_follow_up_ack'),
        AppTexts.localizeMentorMessage(languageCode, ackCode),
        style: const TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: Colors.white54,
        ),
      );
    }

    return Text(
      key: const ValueKey('mentor_reply_ack'),
      '${context.t('mentorReplySentPrefix')}: '
      '${AppTexts.localizeMentorReplyCode(languageCode, message.userReply!)}',
      style: const TextStyle(
        fontSize: 12,
        fontStyle: FontStyle.italic,
        color: Colors.white54,
      ),
    );
  }

  /// Replaces a counter that showed calendar days since the quit date and
  /// never checked whether the user had smoked. This app asks people to cut
  /// down, not to stop outright, so an abstinence streak measured nothing
  /// they were being asked to do — and it went up on days they smoked.
  Widget _buildReductionCard(BuildContext context) {
    final progress = _reductionProgress;
    const accent = Colors.teal;

    return InkWell(
      // The badge grid had no entry point anywhere in the app — it was
      // written, then never linked. The card showing the figures badges are
      // awarded on is the natural place to reach it from.
      borderRadius: BorderRadius.circular(12),
      onTap: progress == null
          ? null
          : () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AchievementsPage(progress: progress),
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: accent.withAlpha((255 * 0.2).toInt()),
          border: Border.all(color: accent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '📉 ${context.t('reductionCardTitle')}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
            const SizedBox(height: 16),
            if (progress == null || !progress.hasVerifiedEvidence) ...[
              // Three confident zeros would read as failure to someone who has
              // simply just installed the app. Say what's missing instead.
              Text(
                context.t('reductionNoDataTitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.t('reductionNoDataBody'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: accent.withAlpha((255 * 0.85).toInt()),
                ),
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildReductionMetric(
                      context,
                      value: '${progress.targetStreakDays}',
                      unit: context.t('dayUnit'),
                      label: context.t('reductionStreakLabel'),
                    ),
                  ),
                  Expanded(
                    child: _buildReductionMetric(
                      context,
                      value: '${progress.cigarettesAvoided}',
                      unit: context.t('cigaretteUnit'),
                      label: context.t('reductionAvoidedLabel'),
                    ),
                  ),
                  Expanded(
                    child: _buildReductionMetric(
                      context,
                      value: '${progress.currentBarrierMinutes}',
                      unit: context.t('minutesShort'),
                      label: context.t('reductionIntervalLabel'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                context
                    .t('reductionTargetToday')
                    .replaceAll('{target}', '${progress.dailyTarget}'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
              if (progress.loggedToday != null)
                Text(
                  context
                      .t('reductionLoggedToday')
                      .replaceAll('{count}', '${progress.loggedToday}'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: accent.withAlpha((255 * 0.85).toInt()),
                  ),
                ),
              if (progress.naturalIntervalMinutes > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${context.t('reductionIntervalDetail').replaceAll('{natural}', '${progress.naturalIntervalMinutes}').replaceAll('{barrier}', '${progress.currentBarrierMinutes}')}'
                  ' • '
                  '${context.t('reductionIntervalGain').replaceAll('{percent}', '${(progress.intervalProgress * 100).round()}')}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: accent.withAlpha((255 * 0.85).toInt()),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReductionMetric(
    BuildContext context, {
    required String value,
    required String unit,
    required String label,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        Text(unit, style: const TextStyle(fontSize: 12, color: Colors.teal)),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            height: 1.25,
            color: Colors.teal.withAlpha((255 * 0.9).toInt()),
          ),
        ),
      ],
    );
  }

  Widget _buildHealthMetricsButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HealthMetricsPage(name: widget.name),
            ),
          );
        },
        icon: const Icon(Icons.show_chart),
        label: Text(context.t('healthMetrics')),
      ),
    );
  }

  Widget _buildSummaryStats(BuildContext context) {
    final score = _adaptiveRiskScore == 0
        ? widget.riskScore
        : _adaptiveRiskScore;
    final hasBreathData = _lastBreathText != 'noRecordYet';
    final breathStatus = _dailyBreathStatus == 'breathTestDoneToday'
        ? context.t('breathTestRecordTitle')
        : context.t('noRecordYet');

    return Column(
      children: [
        Card(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    '$score',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('riskScore'),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${context.t('riskLevel')}: ${_localizedRiskLabel()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$score / 100',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('lastBreathTest'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasBreathData ? _lastBreathText : context.t('noRecordYet'),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text('${context.t('dailyBreathStatus')}: $breathStatus'),
                if (hasBreathData) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${context.t('lastExhale')}: $_latestExhaleSeconds${context.t('secShort')} • ${context.t('lastInhale')}: $_latestInhaleSeconds${context.t('secShort')}',
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${context.t('lastSurveyDate')}: ${_lastSurveyDateText == 'noRecordYet' ? context.t('noRecordYet') : _lastSurveyDateText}',
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildCompleteRegistrationButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isCompletingRegistration ? null : _completeRegistration,
        child: Text(context.t('completeRegistration')),
      ),
    );
  }

  Widget _buildAdaptiveInsightsCard() {
    final triggers = _riskyTriggers.isEmpty
        ? context.t('noRecordYet')
        : _riskyTriggers.map(_localizeCanonicalToken).join(', ');
    final hours = _riskyHours.isEmpty
        ? context.t('noRecordYet')
        : _riskyHours.join(', ');
    final breathTrend = _breathTrendText == 'Improving'
        ? context.t('trendImproving')
        : _breathTrendText == 'Declining'
        ? context.t('trendDeclining')
        : _breathTrendText == 'Stable'
        ? context.t('trendStable')
        : _breathTrendText;
    final progress = _progressSummaryText == 'Improving'
        ? context.t('trendImproving')
        : _progressSummaryText == 'Declining'
        ? context.t('trendDeclining')
        : _progressSummaryText == 'Stable'
        ? context.t('trendStable')
        : _progressSummaryText;
    final cadenceLabel = _planCadenceLevel == 'week'
        ? context.t('goal180CadenceWeek')
        : _planCadenceLevel == 'two_days'
        ? context.t('goal180CadenceTwoDays')
        : context.t('goal180CadenceOneDay');
    final guideText = _planCurrentDay >= 120
        ? (_failedTaskCount > _successfulTaskCount
              ? context.t('goal180GuideLateHard')
              : context.t('goal180GuideLate'))
        : _planCurrentDay >= 60
        ? (_failedTaskCount > _successfulTaskCount
              ? context.t('goal180GuideMidHard')
              : context.t('goal180GuideMid'))
        : context.t('goal180GuideEarly');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('adaptiveSummary'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('${context.t('riskyTriggers')}: $triggers'),
            const SizedBox(height: 6),
            Text('${context.t('riskyHours')}: $hours'),
            const SizedBox(height: 6),
            Text('${context.t('breathImprovementSummary')}: $breathTrend'),
            const SizedBox(height: 6),
            Text('${context.t('progressSummary')}: $progress'),
            const SizedBox(height: 6),
            Text('${context.t('predictedRiskTime')}: $_predictedRiskWindow'),
            const SizedBox(height: 6),
            Text(
              '${context.t('predictedTrigger')}: '
              '${AppTexts.localizeCanonicalText(context, _predictedTrigger)}',
            ),
            const SizedBox(height: 6),
            Text(
              '${context.t('predictionConfidence')}: %$_predictionConfidence',
            ),
            const SizedBox(height: 6),
            Text('${context.t('weeklyRiskTarget')}: $_weeklyRiskTarget / 100'),
            const SizedBox(height: 6),
            Text(
              '${context.t('weeklyRiskLine')}: $_weeklySurveyRiskScore/100 (${_localizedWeeklyRiskLevel()})',
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _respiratoryBandColor().withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _respiratoryBandColor()),
              ),
              child: Text(
                '${context.t('respiratoryStatusLine')}: ${_respiratoryStateLabel()} • ${context.t('levelLabel')}: $_lastRespiratoryBurden/100',
                style: TextStyle(
                  color: _respiratoryBandColor(),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (_riskExplanation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                context.t('riskScoreExplanationTitle'),
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ..._riskExplanation.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '- ${AppTexts.localizeCanonicalTextForCode(Localizations.localeOf(context).languageCode, line)}',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '${context.t('goal180ProgressLabel')}: $_planCurrentDay / $_planTargetDays ${context.t('days')}',
            ),
            const SizedBox(height: 6),
            Text(
              '${context.t('goal180RemainingLabel')}: $_planDaysRemaining ${context.t('days')}',
            ),
            const SizedBox(height: 6),
            Text('${context.t('goal180CadenceLabel')}: $cadenceLabel'),
            const SizedBox(height: 6),
            Text(guideText),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(String titleKey, List<Widget> buttons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t(titleKey),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: buttons),
      ],
    );
  }

  Widget _buildTestsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMenuSection('menuSectionTestsAndSurveys', [
          SizedBox(
            width: 160,
            child: ElevatedButton.icon(
              onPressed: _openBreathTestFromMenu,
              icon: const Icon(Icons.air),
              label: Text(context.t('menuBreathTest')),
            ),
          ),
          SizedBox(
            width: 160,
            child: OutlinedButton.icon(
              onPressed: _openWeeklySurveyFromMenu,
              icon: const Icon(Icons.assignment),
              label: Text(context.t('menuWeeklySurvey')),
            ),
          ),
          SizedBox(
            width: 160,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SurveyHistoryPage()),
                );
              },
              icon: const Icon(Icons.history),
              label: Text(context.t('menuSurveyHistory')),
            ),
          ),
          SizedBox(
            width: 160,
            child: OutlinedButton.icon(
              onPressed: _openCoughTestFromMenu,
              icon: const Icon(Icons.sick_outlined),
              label: Text(context.t('menuCoughTest')),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildTrackingLinkCard({
    required IconData icon,
    required String labelKey,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(context.t(labelKey)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildTrackingTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAdaptiveInsightsCard(),
        const SizedBox(height: 16),
        _buildTaskReasonCard(),
        const SizedBox(height: 16),
        _buildTodayTaskCard(),
        const SizedBox(height: 16),
        _buildConsecutiveSmokingCard(),
        const SizedBox(height: 16),
        _buildTrackingLinkCard(
          icon: Icons.insights,
          labelKey: 'menuPersonalProgress',
          onTap: _openPersonalProgressScreen,
        ),
        const SizedBox(height: 8),
        _buildTrackingLinkCard(
          icon: Icons.show_chart,
          labelKey: 'breathAnalysisPageTitle',
          onTap: _openBreathAnalysisScreen,
        ),
        const SizedBox(height: 8),
        _buildTrackingLinkCard(
          icon: Icons.picture_as_pdf_outlined,
          labelKey: 'menuReports',
          onTap: _openReports,
        ),
        const SizedBox(height: 8),
        _buildTrackingLinkCard(
          icon: Icons.report_gmailerrorred,
          labelKey: 'menuViolationReport',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProtocolViolationsPage()),
            );
          },
        ),
      ],
    );
  }

  /// The card offered when [_missedTaskTitle] is set: a task the overdue-
  /// grace branch of [_notifyNewTasks] closed out as `missed` before the
  /// user ever saw it. Start re-runs the same accept path the mandatory
  /// screen uses; Skip just drops it, same as declining any other task.
  Widget _buildMissedTaskRow() {
    final title = _missedTaskTitle;
    if (title == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('missedTaskCardBody')),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton(
                onPressed: () => unawaited(_skipMissedTask(title)),
                child: Text(context.t('missedTaskSkipLabel')),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => unawaited(_startMissedTask(title)),
                child: Text(context.t('missedTaskStartLabel')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startMissedTask(String taskTitle) async {
    await _storageService.clearMissedTaskTitle();
    if (mounted) {
      setState(() => _missedTaskTitle = null);
    }
    if (!mounted) return;
    final actionId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => MandatoryTaskPage(taskTitle: taskTitle),
      ),
    );
    // Same gap as the mandatory-gate path above: this route into
    // MandatoryTaskPage never has a watchdogId either, so without this the
    // native "waiting for response" foreground notification would stay up
    // regardless of what the user chose on the page — it only used to be
    // acknowledged on acceptance, so declining (or the page otherwise
    // closing without a "done" result) left it stuck until the native
    // watchdog's own 15-minute timeout wrote a violation.
    unawaited(AndroidWatchdogService.acknowledgeWatchdogByTaskTitle(taskTitle));
    if (actionId == null) {
      return;
    }
    final followUp = await TaskAssignmentService(_storageService)
        .handleTaskAction(
          canonicalTitle: taskTitle,
          taskTitle: taskTitle,
          actionId: actionId,
        );
    if (!mounted) return;
    if (followUp == TaskActionFollowUp.openSosPage) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CravingSosPage(taskCanonicalTitle: taskTitle),
        ),
      );
      if (!mounted) return;
    }
    setState(() {
      _taskStates[taskTitle] = _uiStateFor(actionId);
    });
    await _loadHomeMetrics();
  }

  Future<void> _skipMissedTask(String taskTitle) async {
    await _storageService.clearMissedTaskTitle();
    if (mounted) {
      setState(() => _missedTaskTitle = null);
    }
  }

  Widget _buildTodayTaskCard() {
    final tasks = _todaysTasks.isEmpty
        ? <String>[context.t('noTaskToday')]
        : _todaysTasks;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('todaysTasks'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_missedTaskTitle != null) _buildMissedTaskRow(),
            if (_pendingFollowUps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${context.t('taskFollowUpPendingCount')}: ${_pendingFollowUps.length}',
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${context.t('successfulTaskCount')}: $_successfulTaskCount • ${context.t('failedTaskCount')}: $_failedTaskCount',
              ),
            ),
            if (_undeliveredTaskCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  context
                      .t('undeliveredTaskSummary')
                      .replaceAll('{count}', '$_undeliveredTaskCount'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ...tasks.map((task) {
              if (_todaysTasks.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('- $task'),
                );
              }
              final state = _taskStates[task] ?? 'new';
              final translatedState = state == 'completed'
                  ? context.t('taskStateCompleted')
                  : state == 'failed'
                  ? context.t('taskStateFailed')
                  : state == 'deferred'
                  ? context.t('taskStateDeferred')
                  : context.t('taskStateNew');
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('- ${_localizeTaskText(task)}'),
                    const SizedBox(height: 6),
                    Text(translatedState, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskReasonCard() {
    final cadenceLabel = _planCadenceLevel == 'week'
        ? context.t('goal180CadenceWeek')
        : _planCadenceLevel == 'two_days'
        ? context.t('goal180CadenceTwoDays')
        : context.t('goal180CadenceOneDay');
    final recentTotal = _recentSuccessCount + _recentFailureCount;
    final successRatioText = recentTotal == 0
        ? context.t('taskReasonNoRecentData')
        : '%${((_recentSuccessCount * 100) / recentTotal).round()} ($_recentSuccessCount/$recentTotal)';
    final decisionReasons = _buildTaskDecisionReasons();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('taskReasonCardTitle'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              '${context.t('taskReasonRiskLine')}: ${_adaptiveRiskScore == 0 ? widget.riskScore : _adaptiveRiskScore}/100',
            ),
            const SizedBox(height: 6),
            Text('${context.t('taskReasonRecentRatio')}: $successRatioText'),
            const SizedBox(height: 6),
            Text('${context.t('taskReasonCadence')}: $cadenceLabel'),
            const SizedBox(height: 6),
            Text(
              '${context.t('taskReasonNextNotification')}: $_nextTaskNotificationText',
            ),
            const SizedBox(height: 6),
            Text(
              '${context.t('notificationContextReasonLabel')}: $_notificationContextReasonText',
            ),
            const SizedBox(height: 6),
            Text(
              '${context.t('taskReasonCause')}:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            ...decisionReasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        reason.key,
                        size: 14,
                        color: _reasonIconColor(reason.key),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(reason.value)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MapEntry<IconData, String>> _buildTaskDecisionReasons() {
    final effectiveRisk = _adaptiveRiskScore == 0
        ? widget.riskScore
        : _adaptiveRiskScore;
    final recentTotal = _recentSuccessCount + _recentFailureCount;

    final fragments = <MapEntry<IconData, String>>[];

    if (recentTotal == 0) {
      fragments.add(
        MapEntry(Icons.tune_rounded, context.t('taskReasonCauseBootstrap')),
      );
    } else if (_recentFailureCount > _recentSuccessCount) {
      fragments.add(
        MapEntry(
          Icons.trending_up_rounded,
          context.t('taskReasonCauseFailurePressure'),
        ),
      );
    } else if (_recentSuccessCount >= _recentFailureCount + 3) {
      fragments.add(
        MapEntry(
          Icons.verified_rounded,
          context.t('taskReasonCauseSuccessStability'),
        ),
      );
    }

    if (effectiveRisk >= 70) {
      fragments.add(
        MapEntry(
          Icons.warning_amber_rounded,
          context.t('taskReasonCauseHighRisk'),
        ),
      );
    } else if (effectiveRisk <= 35) {
      fragments.add(
        MapEntry(
          Icons.shield_moon_rounded,
          context.t('taskReasonCauseLowRisk'),
        ),
      );
    }

    if (_riskyTriggers.isNotEmpty) {
      fragments.add(
        MapEntry(
          Icons.local_fire_department_rounded,
          '${context.t('taskReasonCauseTopTrigger')} ${_localizeCanonicalToken(_riskyTriggers.first)}',
        ),
      );
    }

    if (_riskyHours.isNotEmpty) {
      fragments.add(
        MapEntry(
          Icons.schedule_rounded,
          '${context.t('taskReasonCauseTopHour')} ${_riskyHours.first}',
        ),
      );
    }

    if (fragments.isEmpty) {
      return [
        MapEntry(Icons.balance_rounded, context.t('taskReasonCauseBalanced')),
      ];
    }
    return fragments;
  }

  Color _reasonIconColor(IconData icon) {
    if (icon == Icons.warning_amber_rounded) {
      return Colors.redAccent;
    }
    if (icon == Icons.trending_up_rounded) {
      return Colors.orangeAccent;
    }
    if (icon == Icons.local_fire_department_rounded) {
      return Colors.deepOrangeAccent;
    }
    if (icon == Icons.schedule_rounded) {
      return Colors.lightBlueAccent;
    }
    if (icon == Icons.verified_rounded) {
      return Colors.lightGreenAccent;
    }
    if (icon == Icons.shield_moon_rounded || icon == Icons.balance_rounded) {
      return Colors.tealAccent;
    }
    if (icon == Icons.tune_rounded) {
      return Colors.purpleAccent;
    }
    return Colors.white70;
  }

  Widget _buildBreathTrendCard() {
    final hasAnyData =
        _dailyAverage > 0 || _weeklyAverage > 0 || _monthlyAverage > 0;
    final maxValue = [
      _dailyAverage,
      _weeklyAverage,
      _monthlyAverage,
    ].reduce((a, b) => a > b ? a : b).clamp(1, 100).toDouble();
    final values = [
      (_dailyAverage / maxValue).clamp(0.0, 1.0),
      (_weeklyAverage / maxValue).clamp(0.0, 1.0),
      (_monthlyAverage / maxValue).clamp(0.0, 1.0),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('breathTrend'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (!hasAnyData)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text(
                    context.t('noRecordYet'),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: 176,
                width: double.infinity,
                child: CustomPaint(
                  painter: _BreathPathPainter(values: values),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildBreathPathLabel(context.t('daily'), false),
                  _buildBreathPathLabel(context.t('weekly'), false),
                  _buildBreathPathLabel(context.t('monthly'), true),
                ],
              ),
              const SizedBox(height: 18),
              _buildBreathMetricRow(
                Icons.air_rounded,
                context.t('daily'),
                _formatBreathValue(_dailyAverage),
              ),
              _buildBreathMetricRow(
                Icons.insights_rounded,
                context.t('weekly'),
                _formatBreathValue(_weeklyAverage),
              ),
              _buildBreathMetricRow(
                Icons.timeline_rounded,
                context.t('monthly'),
                _formatBreathValue(_monthlyAverage),
              ),
            ],
            if (hasAnyData) ...[
              const SizedBox(height: 12),
              _buildTrendSummaryRow(
                context.t('weeklyImprovement'),
                _translateTrend(_weeklyImprovementText),
              ),
              _buildTrendSummaryRow(
                context.t('monthlyImprovement'),
                _translateTrend(_monthlyImprovementText),
              ),
              _buildTrendSummaryRow(
                context.t('breathPreviousComparison'),
                _breathPreviousReportText,
              ),
              _buildTrendSummaryRow(
                context.t('breathAverageComparison'),
                _breathAverageReportText,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrendSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text('$label:')),
          const SizedBox(width: 8),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _buildBreathPathLabel(String label, bool highlighted) {
    return Text(
      label,
      style: TextStyle(
        color: highlighted ? AppTheme.ember : AppTheme.inkMuted,
        fontSize: 11,
        fontWeight: highlighted ? FontWeight.w800 : FontWeight.w500,
      ),
    );
  }

  Widget _buildBreathMetricRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppTheme.brandAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.ember,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBreathValue(double value) {
    if (value <= 0) return '—';
    return value.toStringAsFixed(1);
  }


  Widget _buildConsecutiveSmokingCard() {
    final latest = _consecutiveSmokingLatestText == 'noRecordYet'
        ? context.t('noRecordYet')
        : _localizeConsecutiveLabel(_consecutiveSmokingLatestText);
    final status = _consecutiveSmokingStatusText == 'noRecordYet'
        ? context.t('noRecordYet')
        : _localizeConsecutiveLabel(_consecutiveSmokingStatusText);
    final trend = _consecutiveSmokingTrendText == 'noRecordYet'
        ? context.t('noRecordYet')
        : _consecutiveSmokingTrendText == 'trendStable'
        ? context.t('trendStable')
        : _consecutiveSmokingTrendText == 'trendImproving'
        ? context.t('trendImproving')
        : _consecutiveSmokingTrendText == 'trendDeclining'
        ? context.t('trendDeclining')
        : _consecutiveSmokingTrendText;
    final previous = _consecutiveSmokingPreviousText == 'noRecordYet'
        ? context.t('noRecordYet')
        : _consecutiveSmokingPreviousText == 'firstEvaluation'
        ? context.t('firstEvaluation')
        : _localizeConsecutiveLabel(_consecutiveSmokingPreviousText);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('chainSmokingTrend'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('${context.t('chainSmokingLatest')}: $latest'),
            const SizedBox(height: 6),
            Text('${context.t('status')}: $status'),
            const SizedBox(height: 6),
            Text('${context.t('progressRegression')}: $trend'),
            const SizedBox(height: 6),
            Text('${context.t('previousRecord')}: $previous'),
          ],
        ),
      ),
    );
  }
}


class _BreathPathPainter extends CustomPainter {
  final List<double> values;

  const _BreathPathPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final lineColor = const Color(0xFF9CCDBB);
    final ember = const Color(0xFFE6A15C);
    final guide = const Color(0x149AA9AC);
    final points = <Offset>[];
    final chartHeight = size.height - 24;
    final left = 10.0;
    final right = size.width - 10.0;
    final step = values.length == 1
        ? 0.0
        : (right - left) / (values.length - 1);

    final guidePaint = Paint()
      ..color = guide
      ..strokeWidth = 1;
    for (var i = 0; i < values.length; i++) {
      final x = left + step * i;
      canvas.drawLine(
        Offset(x, chartHeight * 0.18),
        Offset(x, chartHeight),
        guidePaint,
      );
    }

    for (var i = 0; i < values.length; i++) {
      final x = left + step * i;
      final normalized = values[i].clamp(0.0, 1.0);
      final y = chartHeight - (normalized * chartHeight * 0.72) - 8;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final midX = (previous.dx + current.dx) / 2;
      path.cubicTo(midX, previous.dy, midX, current.dy, current.dx, current.dy);
    }

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < points.length; i++) {
      final isLatest = i == points.length - 1;
      if (isLatest) {
        final glowPaint = Paint()
          ..color = ember.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawCircle(points[i], 10, glowPaint);
      }
      final pointPaint = Paint()..color = isLatest ? ember : lineColor;
      canvas.drawCircle(points[i], isLatest ? 7 : 5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BreathPathPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
