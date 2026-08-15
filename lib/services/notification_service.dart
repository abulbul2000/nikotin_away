import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/app_texts.dart';
import '../models/adaptive_task_models.dart';
import '../models/medication.dart';
import '../models/task_assignment.dart';
import '../pages/breath_test_page.dart';
import '../pages/craving_sos_page.dart';
import '../pages/health_tip_page.dart';
import '../pages/medication_reminder_page.dart';
import '../pages/task_smoked_confirm_page.dart';
import '../pages/weekly_survey_page.dart';
import 'android_watchdog_service.dart';
import 'behavior_engine.dart';
import 'language_service.dart';
import 'notification_budget.dart';
import 'phone_state_service.dart';
import 'sleep_probe_service.dart';
import 'smoked_log_button_service.dart';
import 'storage_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  NotificationService.handleBackgroundNotificationResponse(response);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final StreamController<Map<String, String>> _taskActionController =
      StreamController<Map<String, String>>.broadcast();
  static GlobalKey<NavigatorState>? _navigatorKey;

  static void _pushNotificationRoute(Widget page) {
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  static const String _typeBreath = 'breath';
  static const String _typeTaskStart = 'task_start';
  static const String _typeTaskFollowUp = 'task_followup';
  static const String _typeTaskPostpone = 'task_postpone';
  static const String _typeTaskConfirm = 'task_confirm';
  static const String _typeWeeklySurvey = 'weekly_survey';
  static const String _typeHealthTip = 'health_tip';
  static const String _typeMedicationReminder = 'medication_reminder';

  /// "Kabul Et" — starts the no-smoking window. Kept under its original id so
  /// notifications already scheduled on a user's device still resolve after
  /// an update.
  static const String _actionTaskDone = 'task_done';

  /// "Ertele" — opens the 5/10/15 choice below rather than snoozing by a
  /// fixed amount.
  static const String _actionTaskNotNow = 'task_not_now';

  static const String _actionTaskDecline = 'task_decline';
  static const String _actionTaskSos = 'task_sos';

  static const String _actionPostpone5 = 'task_postpone_5';
  static const String _actionPostpone10 = 'task_postpone_10';
  static const String _actionPostpone15 = 'task_postpone_15';

  /// The window elapsed and we're asking whether they got through it.
  ///
  /// Note the polarity: the question is "did you smoke?", so *yes* is the
  /// failure. The older followup_done/smoked_no pair asked the opposite
  /// ("did you complete it?") and are kept only so notifications scheduled
  /// before an update still resolve correctly.
  static const String _actionConfirmSmokedYes = 'confirm_smoked_yes';
  static const String _actionConfirmSmokedNo = 'confirm_smoked_no';

  static const String _actionFollowUpDone = 'followup_done';
  static const String _actionFollowUpLater = 'followup_later';
  static const String _actionSmokedNo = 'smoked_no';

  /// "Tamam" / "Ertele" on a medication reminder. Only these two — no
  /// decline/SOS, unlike the task-trigger notification.
  static const String _actionMedicationTaken = 'medication_taken';
  static const String _actionMedicationPostpone = 'medication_postpone';
  static const Duration _medicationPostponeDelay = Duration(minutes: 15);

  static const String _postponeChannelId = 'task_postpone_channel_v1';
  static const String _taskConfirmChannelId = 'task_confirm_channel_v1';

  /// How many times one task may be postponed, and how many times SOS may be
  /// used on it.
  ///
  /// Both exist so an escape hatch doesn't become the whole flow. Without a
  /// cap, postponing indefinitely quietly turns every task into no task, and
  /// SOS — which suspends the task rather than failing it — becomes the
  /// costless way to never answer one. Two is enough for a genuinely bad
  /// moment and short of a habit.
  static const int maxPostponesPerTask = 2;
  static const int maxSosPerTask = 2;

  /// Accepted barriers left unresolved beyond this period are closed
  /// neutrally when the home screen next refreshes its metrics.
  static const Duration barrierResolutionDeadline = Duration(hours: 2);

  /// The answers a task offers, minus any the user has used up.
  ///
  /// Only SOS opens the app. The other three are recorded in the background
  /// isolate, because a task prompt that yanks the user out of whatever they
  /// were doing to answer it is its own small punishment for engaging. SOS is
  /// the exception on purpose: it leads into a breathing exercise, which is a
  /// screen by nature.
  ///
  /// Exhausted options are dropped rather than shown-and-refused: offering a
  /// button that answers with "no, not any more" is worse than not offering
  /// it, and on the third prompt the honest choices really are accept,
  /// decline, or say nothing.
  static List<AndroidNotificationAction> _taskTriggerActions(
    String code, {
    int postponeCount = 0,
    int sosCount = 0,
  }) {
    return <AndroidNotificationAction>[
      AndroidNotificationAction(
        _actionTaskDone,
        _text(code, 'taskActionDoneLabel'),
        showsUserInterface: false,
        cancelNotification: true,
      ),
      if (postponeCount < maxPostponesPerTask)
        AndroidNotificationAction(
          _actionTaskNotNow,
          _text(code, 'taskActionNotNowLabel'),
          showsUserInterface: false,
          cancelNotification: true,
        ),
      AndroidNotificationAction(
        _actionTaskDecline,
        _text(code, 'taskActionDeclineLabel'),
        showsUserInterface: false,
        cancelNotification: true,
      ),
      if (sosCount < maxSosPerTask)
        AndroidNotificationAction(
          _actionTaskSos,
          _text(code, 'taskActionSosLabel'),
          showsUserInterface: true,
          cancelNotification: true,
        ),
    ];
  }

  /// Reads how much of a task's postpone/SOS allowance is already spent.
  ///
  /// Returns zeroes for anything without a row — tasks issued before the
  /// assignments table existed, and the very first prompt of a new one.
  static Future<(int postponeCount, int sosCount)> _taskAllowanceFor(
    String taskTitle,
  ) async {
    try {
      final task = await StorageService().loadLatestTaskAssignmentByTitle(
        taskTitle,
      );
      if (task == null || task.isTerminal) {
        return (0, 0);
      }
      return (task.postponeCount, task.sosCount);
    } catch (_) {
      return (0, 0);
    }
  }

  /// Asks how long to postpone by, once "Ertele" has been tapped.
  ///
  /// A second notification rather than a dialog, because the whole point is
  /// that answering a task never opens the app. Notification actions can't
  /// nest, so the choice has to arrive as its own prompt.
  static Future<void> showPostponeChoiceNotification({
    required String taskTitle,
  }) async {
    final code = await LanguageService.loadSelectedLanguageCode();
    final id = _postponeChoiceIdFor(taskTitle);

    await _plugin.show(
      id,
      _text(code, 'postponeChoiceTitle'),
      _text(code, 'postponeChoiceBody'),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _postponeChannelId,
          _text(code, 'channelNamePostponeChoice'),
          importance: Importance.high,
          priority: Priority.high,
          // Quiet: the user just answered a loud prompt, and a second alarm
          // for a follow-up question they asked for would read as nagging.
          playSound: false,
          enableVibration: false,
          visibility: NotificationVisibility.private,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              _actionPostpone5,
              _text(code, 'postpone5Label'),
              showsUserInterface: false,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionPostpone10,
              _text(code, 'postpone10Label'),
              showsUserInterface: false,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionPostpone15,
              _text(code, 'postpone15Label'),
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: _categoryPostpone,
        ),
      ),
      payload: jsonEncode({'type': _typeTaskPostpone, 'taskTitle': taskTitle}),
    );
  }

  /// The end-of-window question, scheduled for when the barrier elapses.
  ///
  /// Worded as "did you smoke?", so **yes is the failure**. The older
  /// follow-up asked "did you complete the task?", where yes meant success —
  /// wiring these two the same way would invert every outcome the learning
  /// engine records, which is why the action ids are distinct rather than
  /// reused.
  static Future<void> scheduleTaskConfirmationPrompt({
    required String taskTitle,
    required Duration delay,
  }) async {
    final code = await LanguageService.loadSelectedLanguageCode();
    final scheduleMode = await _resolveAndroidScheduleMode();
    final fireAt = tz.TZDateTime.now(tz.local).add(delay);

    await _plugin.zonedSchedule(
      _confirmIdFor(taskTitle),
      _text(code, 'taskConfirmQuestionTitle'),
      _text(code, 'taskConfirmQuestion'),
      fireAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _taskConfirmChannelId,
          _text(code, 'channelNameTaskConfirm'),
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          sound: _taskAlarmSound,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.private,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              _actionConfirmSmokedYes,
              _text(code, 'taskConfirmYesLabel'),
              showsUserInterface: false,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionConfirmSmokedNo,
              _text(code, 'taskConfirmNoLabel'),
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: _categoryTaskConfirm,
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({'type': _typeTaskConfirm, 'taskTitle': taskTitle}),
    );
  }

  /// Stable per-task ids so a re-issued prompt replaces its predecessor
  /// instead of stacking a second copy of the same question.
  static int _postponeChoiceIdFor(String taskTitle) =>
      (taskTitle.hashCode.abs() % 100000) + 810000;

  static int _confirmIdFor(String taskTitle) =>
      (taskTitle.hashCode.abs() % 100000) + 820000;

  /// Schedules the end-of-barrier resolution prompt using the same stable
  /// notification id and payload as the task-confirmation flow.
  static Future<void> scheduleBarrierResolutionReminder({
    required String taskTitle,
    required Duration delay,
  }) => scheduleTaskConfirmationPrompt(taskTitle: taskTitle, delay: delay);

  /// Cancels a previously scheduled barrier-resolution prompt.
  static Future<void> cancelBarrierResolutionReminder(String taskTitle) async {
    await _plugin.cancel(_confirmIdFor(taskTitle));
  }

  static const String _categoryTaskStart = 'task_start_category';
  static const String _categoryTaskFollowUp = 'task_followup_category';
  static const String _categoryPostpone = 'task_postpone_category';
  static const String _categoryTaskConfirm = 'task_confirm_category';
  // Bumped (v4->v5, v5->v6, v1->v2): Android freezes a channel's
  // sound/vibration settings the first time it's created and ignores code
  // changes afterward unless the channel ID itself changes — this forces
  // a fresh channel on devices that already had the app installed, so the
  // new alarm sound/vibration pattern actually takes effect.
  static const String _taskStartChannelId = 'task_start_channel_v5';
  static const String _taskFollowUpChannelId = 'task_followup_channel_v6';
  static const String _taskEscalationChannelId = 'task_escalation_channel_v2';
  static const String _breathReminderChannelId = 'breath_reminder_channel_v3';
  static const String _weeklySurveyChannelId = 'weekly_survey_channel_v1';
  static const String _sedentaryReminderChannelId =
      'sedentary_reminder_channel_v1';
  static const String _coachCommandChannelId = 'coach_command_channel_v1';
  static const int _sedentaryReminderNotificationId = 920001;
  static const int _breathOverdueNotificationId = 920002;
  static const int _sleepActivityAdvisoryNotificationId = 930001;
  static const int _snoringResultNotificationId = 930002;
  static const int _coughTestResultNotificationId = 930003;
  static const int _weeklySurveyNotificationId = 700001;
  static const int _dailyBreathReminderBaseId = 420100;
  static const int _dailyBreathReminderMaxSlots = 6;
  static const String _healthTipChannelId = 'health_tip_channel_v2';
  static const int _healthTipBaseId = 430100;

  /// Upper bound for [scheduleHealthConditionAdviceNotifications] — mirrors
  /// the range NotificationKindsCard's picker offers. The actual per-day
  /// count (default 3) comes from [StorageService.loadDailyHealthTipCount].
  static const int _healthTipDailyCountMax = 10;

  /// Slots previously used to key the native health-tip-overlay alarm.
  /// Notifications no longer arm that overlay, but the same slot numbers are
  /// still passed to [AndroidWatchdogService.cancelHealthTipTrigger] so any
  /// alarm scheduled by an older app version gets cleared on update.
  static const int _breathOverlaySlotBase = 10;
  static const int _weeklySurveyOverlaySlot = 20;

  /// Routes _syncReminderOverlayRouteFromNative recognises from a queued
  /// native overlay "Open" action (see ReminderOverlayStore).
  static const String _routeBreathTest = 'breathTest';
  static const String _routeWeeklySurvey = 'weeklySurvey';
  static const String _medicationReminderChannelId =
      'medication_reminder_channel_v1';
  static const int _medicationReminderBaseId = 440100;
  static const int _medicationReminderMaxSlots = 30;

  /// Tip key prefixes per condition, numbered from 1 up to
  /// [_healthTipsPerCondition].
  ///
  /// Held as prefixes rather than an explicit list so the pool can grow
  /// without this map turning into hundreds of literals.
  static const Map<String, String> _healthTipPrefixByCondition = {
    'Hipertansiyon': 'healthTipHypertension',
    'Astim': 'healthTipAsthma',
    'Diyabet': 'healthTipDiabetes',
    'KOAH': 'healthTipCopd',
    'Kalp Hastaligi': 'healthTipHeartDisease',
  };

  /// How many tips exist per condition. Missing keys fall back to the
  /// English/Turkish text rather than showing a raw key, so a pool that has
  /// grown ahead of the translations degrades quietly.
  static const int _healthTipsPerCondition = 33;

  /// Picks a tip for the user's conditions, rotating so the same sentence
  /// doesn't arrive with every dose.
  ///
  /// [slot] is the reminder's index in the day, so consecutive doses show
  /// different tips; the day-of-year term keeps it moving across days too.
  /// Returns null when the user reported no conditions.
  static Future<String?> _healthTipFor(String code, int slot) async {
    try {
      final conditions = await StorageService().loadHealthConditions();
      final withTips = conditions
          .where(_healthTipPrefixByCondition.containsKey)
          .toList(growable: false);
      if (withTips.isEmpty) {
        return null;
      }

      final now = DateTime.now();
      final dayOfYear = now.difference(DateTime(now.year)).inDays;
      final condition = withTips[(dayOfYear + slot) % withTips.length];
      final prefix = _healthTipPrefixByCondition[condition]!;
      final index = ((dayOfYear + slot) % _healthTipsPerCondition) + 1;

      final tip = _text(code, '$prefix$index');
      // _text returns the key itself when nothing matches.
      return tip == '$prefix$index' ? null : tip;
    } catch (_) {
      return null;
    }
  }

  static const int _notificationTimeoutMs = 15000;
  static const String _reservedTimesSettingKey =
      'reserved_notification_fire_times';
  // Retry cadence for a mandatory task alert nobody has answered yet: fire
  // again every 5 minutes, up to 3 attempts total, then give up (see
  // _scheduleUnansweredTaskUpdateReminder) -- matches the discipline
  // protocol's explicit retry contract, not an arbitrary escalation delay.
  static const Duration _unansweredReminderDelay = Duration(minutes: 5);
  static const int _maxTaskAttempts = 3;
  static final Int32List _insistentFlag = Int32List.fromList(<int>[4]);
  // A rhythmic buzz-pause-buzz pattern (not one flat 15s vibration) so it
  // actually reads as an alarm clock going off rather than a single long
  // rumble — combined with FLAG_INSISTENT above, Android replays this
  // (sound + vibration together) on a loop until the user responds.
  static final Int64List _taskVibrationPattern = Int64List.fromList(<int>[
    0,
    700,
    400,
    700,
    400,
    700,
    400,
    700,
  ]);
  // Device's own default alarm-clock sound (not the notification chime) —
  // reachable without bundling an audio asset. Combined with
  // AudioAttributesUsage.alarm (routes through the alarm volume stream,
  // not the notification stream) and the insistent flag above, this is
  // what actually makes these sound like a real alarm going off instead
  // of a normal notification ping.
  static const AndroidNotificationSound _taskAlarmSound =
      UriAndroidNotificationSound('content://settings/system/alarm_alert');

  static Stream<Map<String, String>> get taskActionStream =>
      _taskActionController.stream;

  static Future<void> initialize({
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;
    final code = await LanguageService.loadSelectedLanguageCode();
    tz.initializeTimeZones();
    final initSettings = InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        notificationCategories: <DarwinNotificationCategory>[
          DarwinNotificationCategory(
            _categoryTaskStart,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                _actionTaskDone,
                _text(code, 'taskActionDone'),
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
              DarwinNotificationAction.plain(
                _actionTaskNotNow,
                _text(code, 'taskActionNotNow'),
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
            ],
          ),
          DarwinNotificationCategory(
            _categoryTaskFollowUp,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                _actionFollowUpDone,
                _text(code, 'taskActionDone'),
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
              DarwinNotificationAction.plain(
                _actionFollowUpLater,
                _text(code, 'taskActionNotNow'),
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
            ],
          ),
        ],
      ),
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _syncWatchdogViolationsFromNative();
    await syncOverlayStateFromNative();
    await _syncSleepActivityFromNative();
    await _syncSnoringResultFromNative();
    await _syncSmokedLogEventsFromNative();
    await _restoreSmokedLogButton(code);
    await AndroidWatchdogService.setTaskOverlayChannelInfo(
      channelName: _text(code, 'taskOverlayChannelName'),
      channelDescription: _text(code, 'taskOverlayChannelDescription'),
      foregroundBody: _text(code, 'taskOverlayForegroundBody'),
    );
  }

  /// Puts the floating button back after a reboot or a process death.
  ///
  /// Android does not restart the overlay service on its own, so without this
  /// the button disappeared the first time the phone was restarted and never
  /// came back — the switch in settings still read "on", which made it look
  /// like the feature had simply stopped working.
  static Future<void> _restoreSmokedLogButton(String code) async {
    try {
      await SmokedLogButtonService().restoreIfEnabled(
        notificationTitle: _text(code, 'smokedLogButtonNotificationTitle'),
        notificationBody: _text(code, 'smokedLogButtonNotificationBody'),
        actionLabel: _text(code, 'smokedLogButtonAction'),
        menuLabels: {
          'menuTitle': _text(code, 'smokedLogMenuTitle'),
          'menuSosLabel': _text(code, 'smokedLogMenuSos'),
          'menuBreathLabel': _text(code, 'smokedLogMenuBreathTest'),
          'menuOpenLabel': _text(code, 'smokedLogMenuOpen'),
          'menuCancelLabel': _text(code, 'smokedLogMenuCancel'),
          'channelName': _text(code, 'channelNameSmokedLogQuickAction'),
          'channelDescription': _text(
            code,
            'channelDescriptionSmokedLogQuickAction',
          ),
        },
      );
    } catch (_) {
      // Best effort: the user can always toggle it again from settings.
    }
  }

  static Future<void> refreshLocalizedResources() async {
    await initialize(navigatorKey: _navigatorKey);
  }

  /// Writes any quick-log presses the floating button queued while the app
  /// wasn't running.
  ///
  /// The button lives in a native overlay with no Flutter engine behind it, so
  /// it can only leave timestamps in SharedPreferences; nothing reaches the
  /// database until this runs. Without it every press on a locked or closed
  /// phone — which is most of them — would be silently discarded, and both the
  /// weekly barrier review and the risky-hour ranking read from that table.
  static Future<void> _syncSmokedLogEventsFromNative() async {
    try {
      await SmokedLogButtonService().drainPendingEvents();
    } catch (_) {
      // Best effort: a failed drain leaves the entries queued for next launch
      // rather than losing them.
    }
  }

  static Future<void> syncWatchdogViolationsFromNative() {
    return _syncWatchdogViolationsFromNative();
  }

  static Future<void> _syncWatchdogViolationsFromNative() async {
    try {
      final rows = await AndroidWatchdogService.consumeViolations();
      if (rows.isEmpty) {
        return;
      }

      final storage = StorageService();
      for (final row in rows) {
        final type = row['type']?.toString() ?? 'no_response_10_min';
        final taskTitle = row['taskTitle']?.toString();
        final createdAtMillis = (row['createdAtMillis'] as num?)?.toInt();
        final createdAt = createdAtMillis == null
            ? DateTime.now()
            : DateTime.fromMillisecondsSinceEpoch(createdAtMillis);

        await storage.saveProtocolViolation(
          type: type,
          severity: 'high',
          source: 'queued_import',
          taskTitle: taskTitle,
          details:
              'All $_maxTaskAttempts retry attempts passed with no response to task notification.',
          createdAt: createdAt,
        );

        // Close the assignment row too. The watchdog runs natively while the
        // app is dead, so this queue is the only place a fully-unanswered
        // task is ever noticed; without this the row sat in `delivered`
        // forever, still counting against the postpone/SOS allowances and
        // still looking in-flight to anything that reads lifecycle state,
        // while the violation log and the adaptive engine had both already
        // written it off.
        //
        // A terminal transition writes the adaptive outcome itself, so when
        // it succeeds the explicit record below must be skipped — otherwise
        // one ignored task would be scored as two.
        final closedAssignment =
            taskTitle != null &&
            await _transitionTask(taskTitle, TaskLifecycleState.failedMissed);

        // Feeds the same "no response" event into the adaptive engine (see
        // AdaptiveTaskOutcome.missed) so difficultyLevel/streak react to it
        // exactly like any other failed task, not just the violation log.
        // Only meaningful for the canonical adaptive-plan task format --
        // other command types (coach commands, etc.) aren't tracked by the
        // adaptive engine at all, so there's nothing to record for those.
        final adaptiveMatch = closedAssignment || taskTitle == null
            ? null
            : RegExp(r'^ADAPTIVE_NO_SMOKE:(\d+)$').firstMatch(taskTitle.trim());
        if (adaptiveMatch != null) {
          final plannedMinutes =
              int.tryParse(adaptiveMatch.group(1) ?? '') ?? 30;
          await storage.recordAdaptiveTaskOutcome(
            taskTitle: taskTitle!,
            outcome: AdaptiveTaskOutcome.missed,
            plannedDurationMinutes: plannedMinutes,
            scheduledAt: createdAt.subtract(
              _unansweredReminderDelay * _maxTaskAttempts,
            ),
            respondedAt: createdAt,
          );
        }
      }
    } catch (_) {
      // Keep notification flow resilient even if native watchdog sync fails.
    }
  }

  static const Duration _sleepActivityNotificationCooldown = Duration(
    minutes: 30,
  );
  static const String _lastSleepActivityNotificationKey =
      'last_sleep_activity_notification_at';

  /// Drains "user was awake during their sleep window" events queued by the
  /// native sleep probe (see SleepProbeReceiver.kt / SleepActivityStore) and
  /// decides how to respond: a full mandatory task if today's plan quota
  /// isn't met yet (there's still real intervention work to do), or just a
  /// small advisory tip if it already is (no need to escalate). A cooldown
  /// collapses a run of closely-spaced events (the user staying awake
  /// across several 5-minute probe cycles) into a single notification
  /// rather than one per probe.
  static Future<void> _syncSleepActivityFromNative() async {
    try {
      final events = await SleepProbeService.consumeSleepActivityEvents();
      if (events.isEmpty) {
        return;
      }

      final storage = StorageService();
      final lastAtRaw = await storage.loadSetting(
        _lastSleepActivityNotificationKey,
      );
      final lastAt = lastAtRaw == null ? null : DateTime.tryParse(lastAtRaw);
      final now = DateTime.now();
      if (lastAt != null &&
          now.difference(lastAt) < _sleepActivityNotificationCooldown) {
        return;
      }

      await storage.saveSetting(
        _lastSleepActivityNotificationKey,
        now.toIso8601String(),
      );

      final quotaMet = await storage.isDailyTaskQuotaMet(now: now);
      if (quotaMet) {
        await _showSleepActivityAdvisory();
      } else {
        await showFirstTaskTriggerNotification(
          taskTitle: 'ADAPTIVE_NO_SMOKE:30',
          taskDescription: 'ADAPTIVE_NO_SMOKE:30',
        );
      }
    } catch (_) {
      // Keep notification flow resilient even if sleep-activity sync fails.
    }
  }

  static const String _lastSnoringResultNotificationDateKey =
      'last_snoring_result_notification_date';

  /// Tells the user what last night's (opt-in) Snoring Test actually found —
  /// until now the count only ever surfaced if they opened Settings and
  /// looked. Runs once per calendar day (keyed by date, not a rolling
  /// cooldown, since this is a once-a-night summary rather than an
  /// event-driven alert) and only when there's something to report: at
  /// least one probe fired, so the window wasn't skipped entirely.
  static Future<void> _syncSnoringResultFromNative() async {
    try {
      final storage = StorageService();
      final enabled =
          (await storage.loadSetting('snoring_detection_enabled')) == '1';
      if (!enabled) {
        return;
      }

      final today = DateTime.now();
      final todayKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final lastNotifiedKey = await storage.loadSetting(
        _lastSnoringResultNotificationDateKey,
      );
      if (lastNotifiedKey == todayKey) {
        return;
      }

      final since = today.subtract(const Duration(hours: 12));
      final probes = await storage.loadSnoringProbeEventsBetween(
        start: since,
        end: today,
      );
      if (probes.isEmpty) {
        // Nothing sampled yet tonight — don't claim a result before there
        // is one; this same check will run again on the next app open.
        return;
      }

      final snoreCount = probes.where((e) => e.snoreLikely).length;
      await storage.saveSetting(
        _lastSnoringResultNotificationDateKey,
        todayKey,
      );

      final code = await LanguageService.loadSelectedLanguageCode();
      String body;
      if (snoreCount > 0) {
        final healthConditions = await storage.loadHealthConditions();
        final tier = BehaviorEngine().resolveSnoringAdvisoryTier(
          snoreCount: snoreCount,
          healthConditions: healthConditions,
        );
        final tipKey = switch (tier) {
          'mild' => 'snoringTipMild',
          'moderate' => 'snoringTipModerate',
          'severe' => 'snoringTipSevere',
          _ => null,
        };
        final detected = _text(
          code,
          'snoringResultNotificationBodyDetected',
        ).replaceAll('{count}', '$snoreCount');
        body = tipKey == null
            ? detected
            : '$detected\n\n💡 ${_text(code, tipKey)}';
      } else {
        body = _text(code, 'snoringResultNotificationBodyClear');
      }

      await _plugin.show(
        _snoringResultNotificationId,
        _text(code, 'snoringResultNotificationTitle'),
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _healthTipChannelId,
            _text(code, 'channelNameHealthTip'),
            importance: Importance.defaultImportance,
            visibility: NotificationVisibility.private,
            priority: Priority.defaultPriority,
            playSound: true,
            enableVibration: true,
            audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: const DarwinNotificationDetails(presentSound: true),
        ),
        payload: jsonEncode({'type': _typeHealthTip, 'body': body}),
      );
    } catch (_) {
      // Keep notification flow resilient even if snoring-result sync fails.
    }
  }

  static const String _lastCoughResultNotificationDateKey =
      'last_cough_result_notification_date';

  /// Fired directly by CoughTestPage right after a test result is saved —
  /// unlike [_syncSnoringResultFromNative], there's no native-side queue to
  /// drain here: the cough test is user-initiated and synchronous, so the
  /// result is already known the moment this is called. Still capped to
  /// once per calendar day (same key convention as the snoring summary) so
  /// running the test more than once in a day doesn't re-notify for every
  /// attempt — the in-app result screen already shows every result
  /// immediately, this notification is a secondary nudge.
  static Future<void> showCoughTestResultAdvisory({
    required int coughCount,
    required String severityLevel,
  }) async {
    try {
      final storage = StorageService();
      final today = DateTime.now();
      final todayKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final lastNotifiedKey = await storage.loadSetting(
        _lastCoughResultNotificationDateKey,
      );
      if (lastNotifiedKey == todayKey) {
        return;
      }
      await storage.saveSetting(_lastCoughResultNotificationDateKey, todayKey);

      final code = await LanguageService.loadSelectedLanguageCode();
      final body = coughCount > 0
          ? _text(
              code,
              'coughTestResultCount',
            ).replaceAll('{count}', '$coughCount')
          : _text(code, 'coughTestSeverityNormal');

      await _plugin.show(
        _coughTestResultNotificationId,
        _text(code, 'coughTestNotificationTitle'),
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _healthTipChannelId,
            _text(code, 'channelNameHealthTip'),
            importance: Importance.defaultImportance,
            visibility: NotificationVisibility.private,
            priority: Priority.defaultPriority,
            playSound: true,
            enableVibration: true,
            audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: const DarwinNotificationDetails(presentSound: true),
        ),
        payload: jsonEncode({'type': _typeHealthTip, 'body': body}),
      );
    } catch (_) {
      // Keep notification flow resilient even if the cough-result
      // notification fails — the in-app result screen already showed it.
    }
  }

  static Future<void> _showSleepActivityAdvisory() async {
    final code = await LanguageService.loadSelectedLanguageCode();
    final body = _text(code, 'sleepActivityAdvisoryBody');
    await _plugin.show(
      _sleepActivityAdvisoryNotificationId,
      _text(code, 'sleepActivityAdvisoryTitle'),
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _healthTipChannelId,
          _text(code, 'channelNameHealthTip'),
          importance: Importance.defaultImportance,
          visibility: NotificationVisibility.private,
          priority: Priority.defaultPriority,
          playSound: true,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
      payload: jsonEncode({'type': _typeHealthTip, 'body': body}),
    );
  }

  /// Call on app start and every resume: picks up a route a reminder
  /// overlay's "Open" button queued (see ReminderOverlayStore) and navigates
  /// there, then syncs any mandatory-task overlay outcomes the same way.
  static Future<void> syncOverlayStateFromNative() async {
    await _syncReminderOverlayRouteFromNative();
    await _syncTaskOverlayOutcomesFromNative();
  }

  static Future<void> _syncReminderOverlayRouteFromNative() async {
    try {
      final route = await AndroidWatchdogService.consumeReminderOverlayRoute();
      if (route == null || route.isEmpty) {
        return;
      }
      if (route == _routeBreathTest) {
        final hasOnboarded = await StorageService().hasCompletedInitialSurvey();
        if (!hasOnboarded) {
          return;
        }
        _pushNotificationRoute(const BreathTestPage());
        return;
      }
      if (route == _routeWeeklySurvey) {
        _pushNotificationRoute(const WeeklySurveyPage());
      }
    } catch (_) {
      // Keep notification flow resilient even if route sync fails.
    }
  }

  static Future<void> _syncTaskOverlayOutcomesFromNative() async {
    try {
      final rows = await AndroidWatchdogService.consumeTaskOverlayOutcomes();
      for (final row in rows) {
        final outcome = row['outcome']?.toString() ?? '';
        final taskTitle = row['taskTitle']?.toString() ?? '';
        if (taskTitle.isEmpty || outcome.isEmpty) {
          continue;
        }
        // The overlay now offers the same four answers the notification
        // does. Previously anything that wasn't "done" collapsed into
        // "postpone", so a decline recorded through the overlay was scored
        // as a deferral and never reached the learning engine as a failure.
        final actionId = switch (outcome) {
          'done' => _actionTaskDone,
          'postponed' => _actionTaskNotNow,
          'declined' => _actionTaskDecline,
          'sos' => _actionTaskSos,
          _ => _actionTaskNotNow,
        };
        _dispatchTaskAction({
          'type': _typeTaskStart,
          'taskTitle': taskTitle,
          'canonicalTitle': taskTitle,
          'actionId': actionId,
        });
      }
    } catch (_) {
      // Keep notification flow resilient even if overlay outcome sync fails.
    }
  }

  /// Status-only check (no system prompt) — for display in a settings/
  /// permissions screen. Use [ensureNotificationPermission] to actually
  /// request it.
  static Future<bool> areNotificationsEnabled() async {
    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        return await androidPlugin.areNotificationsEnabled() ?? true;
      }
    } catch (_) {
      // Best-effort on unsupported platforms.
    }
    return true;
  }

  static Future<bool> ensureNotificationPermission() async {
    bool enabled = true;
    bool fullScreenGranted = true;

    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        final isEnabled = await androidPlugin.areNotificationsEnabled();
        enabled = (granted ?? true) && (isEnabled ?? true);
      }
    } catch (_) {
      // Keep best-effort behavior on unsupported devices.
    }

    try {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosPlugin != null) {
        final iosGranted =
            await iosPlugin.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            true;
        enabled = enabled && iosGranted;
      }
    } catch (_) {
      // Keep best-effort behavior on unsupported devices.
    }

    try {
      final dynamic androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        final dynamic requested = await androidPlugin
            .requestFullScreenIntentPermission();
        if (requested is bool) {
          fullScreenGranted = requested;
        }

        try {
          final dynamic canUse = await androidPlugin.canUseFullScreenIntent();
          if (canUse is bool) {
            fullScreenGranted = fullScreenGranted && canUse;
          }
        } catch (_) {
          // canUseFullScreenIntent may not exist depending on plugin/API level.
        }
      }
    } catch (_) {
      // Best-effort: fallback to current notification permission state.
    }

    return enabled && fullScreenGranted;
  }

  static Future<void> openExactAlarmSettingsOptional() async {
    try {
      final dynamic androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (_) {
      // Optional action: ignore on unsupported devices/APIs.
    }
  }

  static Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }

    try {
      final canScheduleExact =
          await androidPlugin.canScheduleExactNotifications() ?? false;
      if (canScheduleExact) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (_) {
      // Fallback to inexact scheduling on unsupported devices/APIs.
    }

    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static void _handleNotificationResponse(NotificationResponse response) {
    unawaited(_processNotificationResponse(response, allowNavigation: true));
  }

  static void handleBackgroundNotificationResponse(
    NotificationResponse response,
  ) {
    unawaited(_processNotificationResponse(response, allowNavigation: false));
  }

  static Future<void> _processNotificationResponse(
    NotificationResponse response, {
    required bool allowNavigation,
  }) async {
    final payload = _decodePayload(response.payload);
    if (payload == null) {
      return;
    }

    final reminderId = int.tryParse(payload['reminderId'] ?? '');
    if (reminderId != null) {
      unawaited(_plugin.cancel(reminderId));
    }

    final type = payload['type'];
    if (type == _typeBreath && allowNavigation) {
      // Never deep-link into BreathTestPage before the user has finished
      // the initial survey — a stale/queued daily reminder firing during
      // onboarding (splash/language-select/mid-survey) used to be able to
      // push BreathTestPage over whatever screen was active and, on
      // completion, route straight to HomePage — skipping SurveyPage
      // entirely and leaving the user stranded with no onboarding data.
      final hasOnboarded = await StorageService().hasCompletedInitialSurvey();
      if (!hasOnboarded) {
        return;
      }
      _pushNotificationRoute(const BreathTestPage());

      return;
    }

    if (type == _typeWeeklySurvey) {
      // Action buttons cancel the notification without opening the app (see
      // _taskTriggerActions-style actions above); tapping the body itself is
      // the only path that should land on the survey.
      if (allowNavigation && (response.actionId ?? '').isEmpty) {
        _pushNotificationRoute(const WeeklySurveyPage());
      }
      return;
    }

    if (type == _typeMedicationReminder) {
      final actionId = response.actionId ?? '';
      if (actionId.isEmpty) {
        // Tapping the notification body (not an action button) opens the
        // same full-screen Tamam/Ertele prompt the notification's own
        // actions resolve, instead of silently logging taken/postponed.
        if (allowNavigation) {
          final context = _navigatorKey?.currentContext;
          if (context != null) {
            // ignore: use_build_context_synchronously
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MedicationReminderPage(
                  medicationId: payload['medicationId'] ?? '',
                  medicationName: payload['medicationName'] ?? '',
                ),
              ),
            );
          }
        }
        return;
      }
      unawaited(
        handleMedicationReminderAction(
          actionId: actionId,
          medicationId: payload['medicationId'] ?? '',
          medicationName: payload['medicationName'] ?? '',
        ),
      );
      return;
    }

    if (type == _typeHealthTip) {
      // No action buttons on this notification — only ever reached by
      // tapping the body.
      if (allowNavigation) {
        final context = _navigatorKey?.currentContext;
        if (context != null) {
          // ignore: use_build_context_synchronously
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HealthTipPage(body: payload['body'] ?? ''),
            ),
          );
        }
      }
      return;
    }

    if (type == _typeTaskConfirm) {
      final actionId = response.actionId ?? '';
      final canonicalTitle =
          (payload['canonicalTitle']?.trim().isNotEmpty ?? false)
          ? payload['canonicalTitle']!.trim()
          : (payload['taskTitle'] ?? '');
      if (actionId.isEmpty) {
        // Tapping the body opens the same Içtim/İçmedim question the
        // notification's own action buttons resolve.
        if (allowNavigation) {
          final context = _navigatorKey?.currentContext;
          if (context != null) {
            // ignore: use_build_context_synchronously
            final clean = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => TaskSmokedConfirmPage(
                  taskTitle: payload['taskTitle'] ?? '',
                  canonicalTitle:
                      payload['canonicalTitle'] ?? payload['taskTitle'] ?? '',
                ),
              ),
            );
            if (clean != null && canonicalTitle.isNotEmpty) {
              await _resolveTaskConfirmOutcome(canonicalTitle, smoked: !clean);
            }
          }
        }
        return;
      }
      if (actionId == _actionConfirmSmokedYes) {
        await _resolveTaskConfirmOutcome(canonicalTitle, smoked: true);
      } else if (actionId == _actionConfirmSmokedNo) {
        await _resolveTaskConfirmOutcome(canonicalTitle, smoked: false);
      }
      return;
    }

    if (type == _typeTaskStart || type == _typeTaskFollowUp) {
      final watchdogId = payload['watchdogId']?.trim() ?? '';
      if (watchdogId.isNotEmpty) {
        unawaited(AndroidWatchdogService.acknowledgeWatchdog(watchdogId));
      }

      final actionId = response.actionId;
      final event = {
        'type': type ?? '',
        'taskTitle': payload['taskTitle'] ?? '',
        // Falls back to taskTitle for notifications scheduled before this
        // field existed — they'll simply not resolve to a row, which is the
        // same as the behaviour they already had.
        'canonicalTitle':
            payload['canonicalTitle'] ?? payload['taskTitle'] ?? '',
        // Empty when the user tapped the notification body rather than an
        // action button — home_page.dart's listener treats this as "open the
        // mandatory-task screen now" instead of resolving the task.
        'actionId': actionId ?? '',
      };

      _dispatchTaskAction(event);
    }
  }

  static void _dispatchTaskAction(Map<String, String> event) {
    if (_taskActionController.hasListener) {
      _taskActionController.add(event);
    } else {
      unawaited(_handleActionWithoutUi(event));
    }
  }

  /// Notification actions no longer open the app, so this runs in the
  /// background isolate `notificationTapBackground` spawns — a *cold* isolate
  /// that never ran [initialize] and therefore has none of its static setup.
  /// Everything below schedules follow-up notifications through
  /// `tz.TZDateTime`, which throws unless the timezone database was loaded in
  /// this isolate first. Cheap and idempotent, so it just runs every time.
  static void _ensureIsolateReady() {
    tz.initializeTimeZones();
  }

  /// Moves the task a notification belongs to into [state].
  ///
  /// Payloads carry only the canonical title, so the row has to be found by
  /// it. A no-op when nothing matches: tasks issued before this table existed
  /// have no row, and they should keep working through the older path rather
  /// than throwing here.
  /// Moves the assignment row for [taskTitle] to [state].
  ///
  /// Returns whether a row was actually moved. Callers that also write an
  /// adaptive outcome of their own need to know: a terminal transition
  /// records one itself, so doing both would score the same task twice.
  static Future<bool> _transitionTask(
    String taskTitle,
    String state, {
    int? postponeMinutes,
  }) async {
    try {
      final storage = StorageService();
      final task = await storage.loadLatestTaskAssignmentByTitle(taskTitle);
      if (task == null) {
        return false;
      }
      final updated = await storage.transitionTaskAssignment(
        id: task.id,
        state: state,
        postponeMinutes: postponeMinutes,
      );
      // Null, or already terminal before the call, means nothing moved.
      return updated != null && updated.state == state;
    } catch (_) {
      // Best effort — never let bookkeeping swallow the user's answer.
      return false;
    }
  }

  /// Records the end-of-window answer, shared by the notification's own
  /// Evet/Hayır action buttons and [TaskSmokedConfirmPage]'s full-screen buttons.
  /// "Did you smoke?" — so yes is the failure. Getting this backwards would
  /// invert every outcome the learning engine ever records.
  static Future<void> _resolveTaskConfirmOutcome(
    String canonicalTitle, {
    required bool smoked,
  }) async {
    if (smoked) {
      await _transitionTask(canonicalTitle, TaskLifecycleState.failedSmoked);
      // An admission is also a real cigarette, so it belongs in the same
      // table the quick-log button writes to — otherwise the risky-hour
      // ranking never learns about the ones admitted this way.
      await StorageService().logSmokingNow();
      return;
    }
    await _transitionTask(canonicalTitle, TaskLifecycleState.succeeded);
  }

  /// Opens the craving page for [canonicalTitle], so the breathing exercise
  /// knows which task to hand the user back to afterwards.
  ///
  /// Only reachable when the app is actually running — the SOS action is the
  /// one action declared `showsUserInterface: true`, so Android brings the
  /// app up first. If the navigator isn't ready yet the exercise is simply
  /// skipped; the task is already suspended either way, so nothing is lost
  /// beyond the screen itself.
  static void _openSosPage(String canonicalTitle) {
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CravingSosPage(taskCanonicalTitle: canonicalTitle),
      ),
    );
  }

  static Future<void> _handleActionWithoutUi(Map<String, String> event) async {
    final taskTitle = event['taskTitle']?.trim() ?? '';
    final actionId = event['actionId']?.trim() ?? '';
    if (taskTitle.isEmpty || actionId.isEmpty) {
      return;
    }
    // The exact ADAPTIVE_NO_SMOKE:<minutes> form. taskTitle is what the user
    // reads and varies by language, so it can't identify a stored task.
    final canonicalTitle = (event['canonicalTitle']?.trim().isNotEmpty ?? false)
        ? event['canonicalTitle']!.trim()
        : taskTitle;
    _ensureIsolateReady();

    final storage = StorageService();
    final now = DateTime.now();

    if (actionId == _actionTaskDone) {
      final delay = _resolveInitialTaskDelay(taskTitle);
      // Mirrors what HomePage's foreground handler persists, so a task
      // accepted with the app closed leaves the same trail as one accepted
      // with it open.
      await storage.saveTaskResult(
        taskTitle: taskTitle,
        taskResult: 'started',
        completedAt: now,
      );
      await storage.saveTaskFollowUp(
        taskTitle: taskTitle,
        scheduledAt: now.add(delay),
      );
      await _transitionTask(canonicalTitle, TaskLifecycleState.accepted);
      await showTaskTimerStartedNotification(
        taskTitle: taskTitle,
        duration: delay,
      );
      // The end-of-window question, asked as "did you smoke?". Replaces the
      // old follow-up, which asked whether the task was completed — the same
      // moment, the opposite polarity.
      await scheduleTaskConfirmationPrompt(taskTitle: taskTitle, delay: delay);
      return;
    }

    // "Ertele" asks how long rather than picking for the user.
    if (actionId == _actionTaskNotNow) {
      await showPostponeChoiceNotification(taskTitle: taskTitle);
      return;
    }

    const postponeMinutes = <String, int>{
      _actionPostpone5: 5,
      _actionPostpone10: 10,
      _actionPostpone15: 15,
    };
    final chosen = postponeMinutes[actionId];
    if (chosen != null) {
      await _transitionTask(
        canonicalTitle,
        TaskLifecycleState.postponed,
        postponeMinutes: chosen,
      );
      await scheduleFirstTaskTriggerNotification(
        taskDescription: taskTitle,
        delay: Duration(minutes: chosen),
      );
      return;
    }

    if (actionId == _actionTaskDecline) {
      // Scored as smoking, per the rule agreed for this flow: declining is
      // treated as intending to smoke, so the barrier doesn't keep growing on
      // the strength of tasks that were simply turned down.
      await _transitionTask(canonicalTitle, TaskLifecycleState.failedDeclined);
      return;
    }

    if (actionId == _actionTaskSos) {
      // Suspended, not finished — the breathing exercise runs and hands the
      // user back to this same task afterwards.
      await _transitionTask(canonicalTitle, TaskLifecycleState.sosActive);
      _openSosPage(canonicalTitle);
      return;
    }

    // The end-of-window answer. "Did you smoke?" — so yes is the failure.
    // Getting this backwards would invert every outcome the learning engine
    // ever records, which is why these ids are distinct from the older
    // followup pair rather than reused.
    if (actionId == _actionConfirmSmokedYes) {
      await _resolveTaskConfirmOutcome(canonicalTitle, smoked: true);
      return;
    }
    if (actionId == _actionConfirmSmokedNo) {
      await _resolveTaskConfirmOutcome(canonicalTitle, smoked: false);
      return;
    }

    // The "yes, I got through it" answer. Previously unhandled here: while
    // actions still opened the app, HomePage's listener recorded it. Now that
    // they don't, an unhandled action would silently drop the one outcome
    // that proves a task succeeded.
    if (actionId == _actionFollowUpDone) {
      await storage.recordAdaptiveTaskOutcome(
        taskTitle: taskTitle,
        outcome: AdaptiveTaskOutcome.success,
        plannedDurationMinutes: _resolveInitialTaskDelay(taskTitle).inMinutes,
        respondedAt: now,
      );
      await storage.saveTaskResult(
        taskTitle: taskTitle,
        taskResult: 'willpower_success',
        completedAt: now,
      );
      await storage.resolveTaskFollowUpByTitle(taskTitle);
      return;
    }

    if (actionId == _actionFollowUpLater || actionId == _actionSmokedNo) {
      await scheduleTaskFollowUpReminder(
        taskTitle: taskTitle,
        delay: const Duration(minutes: 10),
      );
    }
  }

  /// "Tamam" logs the dose as taken. "Ertele" logs the postponement and
  /// re-fires the same reminder [_medicationPostponeDelay] later as a
  /// one-off notification — the original daily-recurring notification (see
  /// `matchDateTimeComponents` in [scheduleMedicationReminders]) is left
  /// alone so tomorrow's dose still arrives on schedule.
  ///
  /// Public so [MedicationReminderPage]'s own Tamam/Ertele buttons can call
  /// the exact same logic the notification's action buttons use.
  static Future<void> handleMedicationReminderAction({
    required String actionId,
    required String medicationId,
    required String medicationName,
  }) async {
    if (medicationId.isEmpty) {
      return;
    }
    _ensureIsolateReady();
    final storage = StorageService();

    if (actionId == _actionMedicationTaken) {
      await storage.logMedicationDoseOutcome(
        medicationId: medicationId,
        outcome: 'taken',
      );
      return;
    }

    if (actionId == _actionMedicationPostpone) {
      await storage.logMedicationDoseOutcome(
        medicationId: medicationId,
        outcome: 'postponed',
      );
      await _scheduleMedicationPostponeReminder(
        medicationId: medicationId,
        medicationName: medicationName,
      );
    }
  }

  static Future<void> _scheduleMedicationPostponeReminder({
    required String medicationId,
    required String medicationName,
  }) async {
    final code = await LanguageService.loadSelectedLanguageCode();
    final fireAt = tz.TZDateTime.now(tz.local).add(_medicationPostponeDelay);
    final body = _text(
      code,
      'medicationReminderBody',
    ).replaceAll('{name}', medicationName);

    await _plugin.zonedSchedule(
      // Outside the recurring-slot id range so it can't collide with, or
      // get cancelled by, the daily reminders scheduleMedicationReminders
      // manages.
      _medicationReminderBaseId +
          _medicationReminderMaxSlots +
          (medicationId.hashCode.abs() % 10000),
      _text(code, 'medicationReminderTitle'),
      body,
      fireAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _medicationReminderChannelId,
          _text(code, 'channelNameMedicationReminder'),
          importance: Importance.max,
          visibility: NotificationVisibility.private,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          category: AndroidNotificationCategory.reminder,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              _actionMedicationTaken,
              _text(code, 'taskActionDoneLabel'),
              showsUserInterface: false,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionMedicationPostpone,
              _text(code, 'taskActionNotNowLabel'),
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
      androidScheduleMode: await _resolveAndroidScheduleMode(),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': _typeMedicationReminder,
        'medicationId': medicationId,
        'medicationName': medicationName,
      }),
    );
  }

  static Map<String, String>? _decodePayload(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return data.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return null;
    }
  }

  static int _deriveReminderId(int sourceId) {
    return (sourceId + 1000000000).remainder(2147483647);
  }

  static Duration _resolveInitialTaskDelay(String taskTitle) {
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

  /// Schedules attempt [attempt] (2 or 3) of the unanswered-task retry
  /// chain. Each attempt embeds the *next* attempt's reminderId in its own
  /// payload -- exactly the same "tapping this cancels reminderId" path
  /// _processNotificationResponse already uses for every other notification
  /// type, so responding to any attempt automatically cancels whichever
  /// attempt would have come after it. Recurses to schedule attempt 3 right
  /// after scheduling attempt 2; stops after attempt 3 (no attempt 4) --
  /// if that also goes unanswered, the native NoResponseWatchdogService's
  /// own timeout (armed for the full 3-attempt window, see
  /// scheduleFirstTaskTriggerNotification) is what ultimately marks the
  /// task missed.
  static Future<void> _scheduleUnansweredTaskUpdateReminder({
    required String taskTitle,
    required String type,
    required int reminderId,
    required tz.TZDateTime triggerAt,
    int attempt = 2,
  }) async {
    final code = await LanguageService.loadSelectedLanguageCode();
    final scheduleMode = await _resolveAndroidScheduleMode();
    final isFollowUp = type == _typeTaskFollowUp;
    final title = isFollowUp
        ? _text(code, 'taskFollowUpTitlePush')
        : _text(code, 'taskEscalationTitle');
    final body = isFollowUp
        ? '${_text(code, 'taskFollowUpQuestion')}\n${AppTexts.localizeCanonicalTextForCode(code, taskTitle)}'
        : '${_text(code, 'taskEscalationBodyPrefix')}\n${AppTexts.localizeCanonicalTextForCode(code, taskTitle)}';
    final androidCategory = AndroidNotificationCategory.reminder;
    final iosCategory = isFollowUp ? _categoryTaskFollowUp : _categoryTaskStart;

    final hasNextAttempt = attempt < _maxTaskAttempts;
    final nextReminderId = hasNextAttempt
        ? _deriveReminderId(reminderId)
        : null;
    final nextTriggerAt = hasNextAttempt
        ? triggerAt.add(_unansweredReminderDelay)
        : null;

    await _plugin.zonedSchedule(
      reminderId,
      title,
      body,
      triggerAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _taskEscalationChannelId,
          _text(code, 'channelNameTaskUpdateReminder'),
          importance: Importance.max,
          visibility: NotificationVisibility.private,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          sound: _taskAlarmSound,
          additionalFlags: _insistentFlag,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          timeoutAfter: _notificationTimeoutMs,
          category: androidCategory,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              isFollowUp ? _actionFollowUpDone : _actionTaskDone,
              _text(code, 'taskActionDoneLabel'),
              showsUserInterface: false,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              isFollowUp ? _actionFollowUpLater : _actionTaskNotNow,
              _text(code, 'taskActionNotNowLabel'),
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: iosCategory,
          presentSound: true,
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': type,
        'taskTitle': taskTitle,
        if (nextReminderId != null) 'reminderId': '$nextReminderId',
      }),
    );

    if (hasNextAttempt && nextReminderId != null && nextTriggerAt != null) {
      await _scheduleUnansweredTaskUpdateReminder(
        taskTitle: taskTitle,
        type: type,
        reminderId: nextReminderId,
        triggerAt: nextTriggerAt,
        attempt: attempt + 1,
      );
    }
  }

  static Future<void> showFirstTaskTriggerNotification({
    required String taskTitle,
    required String taskDescription,
  }) async {
    final code = await LanguageService.loadSelectedLanguageCode();
    final interruptionContext = await _resolveInterruptionContext();
    final contextLabel =
        interruptionContext['contextLabel']?.toString() ?? 'normal';
    final confidence =
        (interruptionContext['confidence'] as num?)?.toDouble() ?? 0.0;
    await _persistNotificationContext(
      code: code,
      contextLabel: contextLabel,
      confidence: confidence,
    );
    final allowance = await _taskAllowanceFor(taskDescription);
    final adjustedDescription = contextLabel == 'eating'
        ? _text(code, 'postMealShieldCommand')
        : AppTexts.localizeCanonicalTextForCode(code, taskDescription);
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    final reminderId = _deriveReminderId(id);
    final watchdogId = 'wdg_$id';
    // Spans the full retry chain (all _maxTaskAttempts, 5 min apart), not
    // just the first interval -- the watchdog should only fire its "truly
    // no response" violation once every attempt has had its turn.
    final dueAt = DateTime.now().add(
      _unansweredReminderDelay * _maxTaskAttempts,
    );
    await _plugin.show(
      id,
      _text(code, 'disciplineCommand'),
      '${_text(code, 'disciplineCommandBody')}\n$adjustedDescription',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _taskStartChannelId,
          _text(code, 'channelNameFirstTaskTrigger'),
          importance: Importance.max,
          visibility: NotificationVisibility.private,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          sound: _taskAlarmSound,
          additionalFlags: _insistentFlag,
          autoCancel: false,
          ongoing: true,
          onlyAlertOnce: false,
          timeoutAfter: _notificationTimeoutMs,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: AndroidNotificationCategory.reminder,
          actions: _taskTriggerActions(
            code,
            postponeCount: allowance.$1,
            sosCount: allowance.$2,
          ),
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: _categoryTaskStart,
        ),
      ),
      payload: jsonEncode({
        'type': _typeTaskStart,
        'taskTitle': taskTitle,
        // The exact ADAPTIVE_NO_SMOKE:<minutes> form, carried separately.
        // `taskTitle` here is the on-screen heading and the other trigger
        // notification puts localised text in the same field, so neither can
        // be matched back to a task_assignments row — a lookup on them finds
        // nothing and silently does nothing.
        'canonicalTitle': taskDescription,
        'reminderId': '$reminderId',
        'watchdogId': watchdogId,
      }),
    );

    await AndroidWatchdogService.startWatchdog(
      taskTitle: taskTitle,
      watchdogId: watchdogId,
      dueAt: dueAt,
      foregroundBody: _text(code, 'watchdogForegroundBody'),
      violationTitle: _text(code, 'watchdogViolationTitle'),
      violationBody: _text(code, 'watchdogViolationBody'),
      foregroundChannelName: _text(code, 'watchdogForegroundChannel'),
      violationChannelName: _text(code, 'watchdogViolationChannel'),
    );

    final reminderAt = tz.TZDateTime.now(
      tz.local,
    ).add(_unansweredReminderDelay);
    await _scheduleUnansweredTaskUpdateReminder(
      taskTitle: taskTitle,
      type: _typeTaskStart,
      reminderId: reminderId,
      triggerAt: reminderAt,
    );
  }

  static Future<void> scheduleFirstTaskTriggerNotification({
    required String taskDescription,
    Duration delay = const Duration(minutes: 10),
  }) async {
    final code = await LanguageService.loadSelectedLanguageCode();
    final scheduleMode = await _resolveAndroidScheduleMode();
    final interruptionContext = await _resolveInterruptionContext();
    final extraDelay =
        (interruptionContext['recommendedDeferralMinutes'] as int?) ?? 0;
    final contextLabel =
        interruptionContext['contextLabel']?.toString() ?? 'normal';
    final confidence =
        (interruptionContext['confidence'] as num?)?.toDouble() ?? 0.0;
    await _persistNotificationContext(
      code: code,
      contextLabel: contextLabel,
      confidence: confidence,
    );
    final now = tz.TZDateTime.now(tz.local);
    var fireAt = now.add(delay).add(Duration(minutes: extraDelay));
    // Tasks and health tips share one reservation ledger. This prevents a task
    // from landing on a health-tip slot (or vice versa) and keeps at least the
    // global 25-minute spacing between notification moments.
    fireAt = await _reserveNonConflictingTime(fireAt);
    final allowance = await _taskAllowanceFor(taskDescription);
    final adjustedDescription = contextLabel == 'eating'
        ? _text(code, 'postMealShieldCommand')
        : AppTexts.localizeCanonicalTextForCode(code, taskDescription);
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    final reminderId = _deriveReminderId(id);
    final watchdogId = 'wdg_$id';
    await _plugin.zonedSchedule(
      id,
      _text(code, 'disciplineCommand'),
      '${_text(code, 'disciplineCommandBody')}\n$adjustedDescription',
      fireAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _taskStartChannelId,
          _text(code, 'channelNameFirstTaskTrigger'),
          importance: Importance.max,
          visibility: NotificationVisibility.private,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          sound: _taskAlarmSound,
          additionalFlags: _insistentFlag,
          autoCancel: false,
          ongoing: true,
          onlyAlertOnce: false,
          timeoutAfter: _notificationTimeoutMs,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: AndroidNotificationCategory.reminder,
          actions: _taskTriggerActions(
            code,
            postponeCount: allowance.$1,
            sosCount: allowance.$2,
          ),
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: _categoryTaskStart,
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': _typeTaskStart,
        'taskTitle': adjustedDescription,
        // See showFirstTaskTriggerNotification: adjustedDescription is the
        // localised, user-facing wording, so the canonical form has to travel
        // alongside it for the task row to be findable.
        'canonicalTitle': taskDescription,
        'reminderId': '$reminderId',
        'watchdogId': watchdogId,
      }),
    );

    // Armed for [fireAt], not for now: the overlay has to be raised at the
    // moment the task is actually due (a scheduled notification can't start
    // it, and with the app closed no Dart is running then), and the watchdog
    // has to start counting from when the user was really asked. Starting it
    // here instead would have it poll in the foreground for however many
    // hours away the task is — and, because WatchdogStore keeps a single
    // active entry, two tasks scheduled in the same session would overwrite
    // each other's watchdog.
    await AndroidWatchdogService.scheduleTaskTrigger(
      title: _text(code, 'disciplineCommand'),
      body: adjustedDescription,
      // Blank when the allowance is spent, so the overlay shows exactly the
      // same answers the notification does.
      doneLabel: _text(code, 'taskActionDoneLabel'),
      postponeLabel: allowance.$1 < maxPostponesPerTask
          ? _text(code, 'taskActionNotNowLabel')
          : '',
      declineLabel: _text(code, 'taskActionDeclineLabel'),
      sosLabel: allowance.$2 < maxSosPerTask
          ? _text(code, 'taskActionSosLabel')
          : '',
      watchdogId: watchdogId,
      taskTitle: adjustedDescription,
      triggerAt: fireAt,
      watchdogWindow: _unansweredReminderDelay * _maxTaskAttempts,
      watchdogForegroundBody: _text(code, 'watchdogForegroundBody'),
      watchdogViolationTitle: _text(code, 'watchdogViolationTitle'),
      watchdogViolationBody: _text(code, 'watchdogViolationBody'),
      watchdogForegroundChannelName: _text(code, 'watchdogForegroundChannel'),
      watchdogViolationChannelName: _text(code, 'watchdogViolationChannel'),
    );

    await _scheduleUnansweredTaskUpdateReminder(
      taskTitle: adjustedDescription,
      type: _typeTaskStart,
      reminderId: reminderId,
      triggerAt: fireAt.add(_unansweredReminderDelay),
    );
  }

  /// The instant at which the clock on the user's phone reads [hour]:[minute].
  ///
  /// `tz.local` is UTC in this app — `setLocalLocation` is never called,
  /// because nothing here can resolve the device's IANA zone name. That made
  /// `tz.TZDateTime(tz.local, y, m, d, hour, minute)` mean "that wall clock in
  /// UTC": someone in UTC+3 asking to be reminded at 21:00 was scheduled for
  /// 00:00 the following day. Building from a plain local [DateTime] instead
  /// pins the correct absolute instant, which is what `absoluteTime`
  /// scheduling actually consumes — no timezone-name lookup needed.
  static tz.TZDateTime _atDeviceTimeOfDay(
    int hour,
    int minute, {
    int addDays = 0,
  }) {
    final today = DateTime.now();
    return tz.TZDateTime.from(
      DateTime(today.year, today.month, today.day + addDays, hour, minute),
      tz.local,
    );
  }

  static Future<void> scheduleDailyBreathReminder({
    required String sleepTime,
  }) async {
    await scheduleAdaptiveDailyBreathReminders(
      sleepTime: sleepTime,
      wakeTime: '07:00',
      minimumCount: 1,
      preferredCount: 1,
    );
  }

  static Future<void> scheduleAdaptiveDailyBreathReminders({
    required String sleepTime,
    required String wakeTime,
    int minimumCount = 1,
    int preferredCount = 1,
  }) async {
    final scheduleMode = await _resolveAndroidScheduleMode();
    final code = await LanguageService.loadSelectedLanguageCode();
    final now = tz.TZDateTime.now(tz.local);
    var safeMinimum = minimumCount < 1 ? 1 : minimumCount;
    if (safeMinimum > _dailyBreathReminderMaxSlots) {
      safeMinimum = _dailyBreathReminderMaxSlots;
    }
    var safePreferred = preferredCount < safeMinimum
        ? safeMinimum
        : preferredCount;
    if (safePreferred > _dailyBreathReminderMaxSlots) {
      safePreferred = _dailyBreathReminderMaxSlots;
    }

    // Same drift problem as scheduleHealthConditionAdviceNotifications: the
    // caller's wakeTime/sleepTime is the static survey/settings value, which
    // can go stale once Sleep Intelligence has a better read on when the
    // user is actually awake.
    final effectiveWindow = await StorageService().resolveEffectiveSleepWindow(
      fallbackSleepTime: sleepTime,
      fallbackWakeTime: wakeTime,
    );
    final resolvedWakeTime = effectiveWindow.wakeTime ?? wakeTime;
    final resolvedSleepTime = effectiveWindow.sleepTime ?? sleepTime;

    final wakeParts = resolvedWakeTime.split(':');
    final wakeHour = int.tryParse(wakeParts[0]) ?? 7;
    final wakeMinute = int.tryParse(wakeParts[1]) ?? 0;

    final sleepParts = resolvedSleepTime.split(':');
    final sleepHour = int.tryParse(sleepParts[0]) ?? 21;
    final sleepMinute = int.tryParse(sleepParts[1]) ?? 0;

    var wakeAt = _atDeviceTimeOfDay(wakeHour, wakeMinute);
    var sleepAt = _atDeviceTimeOfDay(sleepHour, sleepMinute);
    if (!sleepAt.isAfter(wakeAt)) {
      sleepAt = sleepAt.add(const Duration(days: 1));
    }

    final windowMinutes = sleepAt.difference(wakeAt).inMinutes;
    final count = safePreferred;
    // For the common single-reminder case, land near bedtime rather than
    // the middle of the day — the app's daily touchpoint is meant to be one
    // consolidated evening moment, not a random daytime interruption. Only
    // when the adaptive target has escalated above 1 (e.g. worsening
    // respiratory burden calling for closer monitoring) do reminders spread
    // across the day as before.
    const preBedtimeBufferMinutes = 45;
    final intervalMinutes = count <= 1
        ? (windowMinutes - preBedtimeBufferMinutes).clamp(1, windowMinutes)
        : (windowMinutes ~/ (count + 1));

    for (var i = 0; i < _dailyBreathReminderMaxSlots; i++) {
      await _plugin.cancel(_dailyBreathReminderBaseId + i);
      await AndroidWatchdogService.cancelHealthTipTrigger(
        _breathOverlaySlotBase + i,
      );
    }

    for (var i = 0; i < count; i++) {
      var fireAt = wakeAt.add(Duration(minutes: intervalMinutes * (i + 1)));
      if (!fireAt.isAfter(now)) {
        fireAt = fireAt.add(const Duration(days: 1));
      }

      final interruptionContext = await _resolveInterruptionContext();
      final extraDelay =
          (interruptionContext['recommendedDeferralMinutes'] as int?) ?? 0;
      final contextLabel =
          interruptionContext['contextLabel']?.toString() ?? 'normal';
      final confidence =
          (interruptionContext['confidence'] as num?)?.toDouble() ?? 0.0;
      await _persistNotificationContext(
        code: code,
        contextLabel: contextLabel,
        confidence: confidence,
      );
      fireAt = fireAt.add(Duration(minutes: extraDelay));
      fireAt = await _reserveNonConflictingTime(fireAt);

      final body = contextLabel == 'driving'
          ? _text(code, 'breathReminderDriving')
          : contextLabel == 'workout'
          ? _text(code, 'breathReminderWorkout')
          : contextLabel == 'eating'
          ? _text(code, 'breathReminderPostMeal')
          : _text(code, 'breathReminderBody');

      await _plugin.zonedSchedule(
        _dailyBreathReminderBaseId + i,
        _text(code, 'breathReminderTitle'),
        body,
        fireAt,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _breathReminderChannelId,
            _text(code, 'channelNameBreathTestReminder'),
            importance: Importance.max,
            visibility: NotificationVisibility.private,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            vibrationPattern: _taskVibrationPattern,
            audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: const DarwinNotificationDetails(presentSound: true),
        ),
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode({'type': _typeBreath}),
      );
    }

    if (safeMinimum <= count) {
      return;
    }

    // Safety net: if preferred count somehow falls below minimum.
    for (var i = count; i < safeMinimum; i++) {
      final fallbackAt = await _reserveNonConflictingTime(
        now.add(Duration(minutes: 60 + (i * 45))),
      );
      await _plugin.zonedSchedule(
        _dailyBreathReminderBaseId + i,
        _text(code, 'breathReminderTitle'),
        _text(code, 'breathReminderBody'),
        fallbackAt,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _breathReminderChannelId,
            _text(code, 'channelNameBreathTestReminder'),
            importance: Importance.max,
            visibility: NotificationVisibility.private,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            vibrationPattern: _taskVibrationPattern,
            audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: const DarwinNotificationDetails(presentSound: true),
        ),
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode({'type': _typeBreath}),
      );
    }
  }

  /// A few short, condition-specific tips spread across the user's waking
  /// hours — cycles through whichever conditions the user picked in the
  /// initial survey (see SurveyPage._selectedHealthConditions), rotating
  /// which condition's tip lands in each daily slot rather than always
  /// leading with the same one. No-ops (after clearing any previously
  /// scheduled slots) when the user selected no conditions.
  static Future<void> scheduleHealthConditionAdviceNotifications({
    required List<String> healthConditions,
    required String wakeTime,
    required String sleepTime,
  }) async {
    for (var i = 0; i < _healthTipDailyCountMax; i++) {
      await _plugin.cancel(_healthTipBaseId + i);
      await AndroidWatchdogService.cancelHealthTipTrigger(i);
    }
    if (healthConditions.isEmpty) {
      return;
    }

    // The caller passes the static survey/settings window, but the user's
    // actual sleep schedule can drift from that over time. Sleep
    // Intelligence (when enabled) tracks the real window from overnight
    // probes — resolve against that so tips land in waking hours instead of
    // the stale configured ones.
    final effectiveWindow = await StorageService().resolveEffectiveSleepWindow(
      fallbackSleepTime: sleepTime,
      fallbackWakeTime: wakeTime,
    );
    final resolvedWakeTime = effectiveWindow.wakeTime ?? wakeTime;
    final resolvedSleepTime = effectiveWindow.sleepTime ?? sleepTime;

    // Anyone with medication already gets their tip attached to a reminder
    // they receive anyway (see scheduleMedicationReminders). Sending this as
    // well would say the same thing twice in one day.
    final takesMedication =
        (await StorageService().loadMedications()).isNotEmpty;
    if (takesMedication) {
      return;
    }

    // This mode intentionally delivers the full daily health-tip quota.
    // The ten slots are distributed across the resolved waking window below;
    // sleep hours are never used as candidates.
    final dailyCount = _healthTipDailyCountMax;

    final scheduleMode = await _resolveAndroidScheduleMode();
    final code = await LanguageService.loadSelectedLanguageCode();
    final now = tz.TZDateTime.now(tz.local);

    final wakeParts = resolvedWakeTime.split(':');
    final wakeHour = int.tryParse(wakeParts[0]) ?? 7;
    final wakeMinute =
        int.tryParse(wakeParts.length > 1 ? wakeParts[1] : '0') ?? 0;

    final sleepParts = resolvedSleepTime.split(':');
    final sleepHour = int.tryParse(sleepParts[0]) ?? 21;
    final sleepMinute =
        int.tryParse(sleepParts.length > 1 ? sleepParts[1] : '0') ?? 0;

    var wakeAt = _atDeviceTimeOfDay(wakeHour, wakeMinute);
    var sleepAt = _atDeviceTimeOfDay(sleepHour, sleepMinute);
    if (!sleepAt.isAfter(wakeAt)) {
      sleepAt = sleepAt.add(const Duration(days: 1));
    }

    final windowMinutes = sleepAt.difference(wakeAt).inMinutes;
    final intervalMinutes = windowMinutes ~/ (dailyCount + 1);

    var conditionCursor = 0;
    var variantCursor = 0;
    for (var i = 0; i < dailyCount; i++) {
      var fireAt = wakeAt.add(Duration(minutes: intervalMinutes * (i + 1)));
      if (!fireAt.isAfter(now)) {
        fireAt = fireAt.add(const Duration(days: 1));
      }
      fireAt = await _reserveNonConflictingTime(fireAt);
      if (!await _budgetAllows(
        NotificationKind.healthTip,
        at: fireAt,
        lowestPendingOfferedPriority: const NotificationBudget().priorityOf(
          NotificationKind.healthTip,
        ),
      )) {
        continue;
      }

      final condition =
          healthConditions[conditionCursor % healthConditions.length];
      final prefix = _healthTipPrefixByCondition[condition];
      conditionCursor++;
      if (prefix == null) {
        continue;
      }
      final tipKey = '$prefix${(variantCursor % _healthTipsPerCondition) + 1}';
      variantCursor++;
      final body =
          '${_text(code, tipKey)}\n${_text(code, 'medicationAdviceDisclaimer')}';

      await _plugin.zonedSchedule(
        _healthTipBaseId + i,
        _text(code, 'healthTipTitle'),
        body,
        fireAt,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _healthTipChannelId,
            _text(code, 'channelNameHealthTip'),
            importance: Importance.max,
            visibility: NotificationVisibility.private,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            vibrationPattern: _taskVibrationPattern,
            audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: const DarwinNotificationDetails(presentSound: true),
        ),
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode({'type': _typeHealthTip, 'body': body}),
      );
    }
  }

  static Future<void> scheduleMedicationReminders(
    List<Medication> medications,
  ) async {
    for (var i = 0; i < _medicationReminderMaxSlots; i++) {
      await _plugin.cancel(_medicationReminderBaseId + i);
    }
    if (medications.isEmpty) {
      return;
    }

    final scheduleMode = await _resolveAndroidScheduleMode();
    final code = await LanguageService.loadSelectedLanguageCode();
    final now = tz.TZDateTime.now(tz.local);

    var slot = 0;
    for (final medication in medications) {
      for (final time in medication.times) {
        if (slot >= _medicationReminderMaxSlots) {
          return;
        }
        final parts = time.split(':');
        final hour = int.tryParse(parts[0]) ?? 8;
        final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
        var fireAt = _atDeviceTimeOfDay(hour, minute);
        if (!fireAt.isAfter(now)) {
          fireAt = fireAt.add(const Duration(days: 1));
        }
        fireAt = await _reserveNonConflictingTime(fireAt);

        final reminder = _text(
          code,
          'medicationReminderBody',
        ).replaceAll('{name}', medication.name);

        // The condition-specific tip rides along with a notification the user
        // already receives, instead of arriving as its own. Three separate
        // advice notifications a day was the previous design and it read as
        // nagging; this reaches the same person at a moment they're already
        // thinking about their health, at no extra interruption.
        final tip = await _healthTipFor(code, slot);
        final body = tip == null
            ? reminder
            : '$reminder\n\n💡 $tip\n${_text(code, 'medicationAdviceDisclaimer')}';

        await _plugin.zonedSchedule(
          _medicationReminderBaseId + slot,
          _text(code, 'medicationReminderTitle'),
          body,
          fireAt,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _medicationReminderChannelId,
              _text(code, 'channelNameMedicationReminder'),
              importance: Importance.max,
              visibility: NotificationVisibility.private,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              vibrationPattern: _taskVibrationPattern,
              audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
              category: AndroidNotificationCategory.reminder,
              actions: <AndroidNotificationAction>[
                AndroidNotificationAction(
                  _actionMedicationTaken,
                  _text(code, 'taskActionDoneLabel'),
                  showsUserInterface: false,
                  cancelNotification: true,
                ),
                AndroidNotificationAction(
                  _actionMedicationPostpone,
                  _text(code, 'taskActionNotNowLabel'),
                  showsUserInterface: false,
                  cancelNotification: true,
                ),
              ],
            ),
            iOS: const DarwinNotificationDetails(presentSound: true),
          ),
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: DateTimeComponents.time,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: jsonEncode({
            'type': _typeMedicationReminder,
            'medicationId': medication.id,
            'medicationName': medication.name,
          }),
        );
        slot++;
      }
    }
  }

  static Future<void> scheduleTaskFollowUpReminder({
    required String taskTitle,
    Duration delay = const Duration(minutes: 30),
  }) async {
    final scheduleMode = await _resolveAndroidScheduleMode();
    final code = await LanguageService.loadSelectedLanguageCode();
    final now = tz.TZDateTime.now(tz.local);
    final interruptionContext = await _resolveInterruptionContext();
    final extraDelay =
        (interruptionContext['recommendedDeferralMinutes'] as int?) ?? 0;
    final contextLabel =
        interruptionContext['contextLabel']?.toString() ?? 'normal';
    final confidence =
        (interruptionContext['confidence'] as num?)?.toDouble() ?? 0.0;
    await _persistNotificationContext(
      code: code,
      contextLabel: contextLabel,
      confidence: confidence,
    );
    var fireAt = now.add(delay).add(Duration(minutes: extraDelay));

    final followUpBody = contextLabel == 'driving'
        ? _text(code, 'taskFollowUpQuestionDriving')
        : contextLabel == 'workout'
        ? _text(code, 'taskFollowUpQuestionWorkout')
        : contextLabel == 'eating'
        ? _text(code, 'taskFollowUpQuestionPostMeal')
        : '${_text(code, 'taskFollowUpQuestion')}\n${AppTexts.localizeCanonicalTextForCode(code, taskTitle)}';

    final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      2147483647,
    );
    final reminderId = _deriveReminderId(notificationId);

    await _plugin.zonedSchedule(
      notificationId,
      _text(code, 'taskFollowUpTitlePush'),
      followUpBody,
      fireAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _taskFollowUpChannelId,
          _text(code, 'channelNameTaskFollowUpReminder'),
          importance: Importance.max,
          visibility: NotificationVisibility.private,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          sound: _taskAlarmSound,
          additionalFlags: _insistentFlag,
          autoCancel: true,
          onlyAlertOnce: false,
          timeoutAfter: _notificationTimeoutMs,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: AndroidNotificationCategory.reminder,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              _actionFollowUpDone,
              _text(code, 'taskActionDoneLabel'),
              showsUserInterface: false,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionFollowUpLater,
              _text(code, 'taskActionNotNowLabel'),
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: _categoryTaskFollowUp,
          presentSound: true,
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': _typeTaskFollowUp,
        'taskTitle': taskTitle,
        'reminderId': '$reminderId',
      }),
    );

    await _scheduleUnansweredTaskUpdateReminder(
      taskTitle: taskTitle,
      type: _typeTaskFollowUp,
      reminderId: reminderId,
      triggerAt: fireAt.add(_unansweredReminderDelay),
    );
  }

  static Future<void> scheduleWeeklySurveyDueReminder({
    required DateTime dueAt,
    bool forceImmediateIfOverdue = true,
  }) async {
    final scheduleMode = await _resolveAndroidScheduleMode();
    final code = await LanguageService.loadSelectedLanguageCode();
    final now = tz.TZDateTime.now(tz.local);
    var fireAt = tz.TZDateTime.from(dueAt, tz.local);
    if (!fireAt.isAfter(now)) {
      if (!forceImmediateIfOverdue) {
        return;
      }
      fireAt = now.add(const Duration(minutes: 1));
    }
    // Not run through the daily budget: this fires at most once a week, so
    // the risk of budget exhaustion pushing it into next week outweighs the
    // benefit of coordinating with same-day notifications. The shared
    // spacing gap still applies.
    fireAt = await _reserveNonConflictingTime(fireAt);

    await _plugin.cancel(_weeklySurveyNotificationId);
    await _plugin.zonedSchedule(
      _weeklySurveyNotificationId,
      _text(code, 'weeklySurveyReminderTitle'),
      _text(code, 'weeklySurveyReminderBody'),
      fireAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _weeklySurveyChannelId,
          _text(code, 'channelNameWeeklySurveyReminder'),
          importance: Importance.max,
          visibility: NotificationVisibility.private,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({'type': _typeWeeklySurvey}),
    );
  }

  static Future<void> cancelWeeklySurveyReminder() async {
    await _plugin.cancel(_weeklySurveyNotificationId);
    await AndroidWatchdogService.cancelHealthTipTrigger(
      _weeklySurveyOverlaySlot,
    );
  }

  static Future<void> showTaskTimerStartedNotification({
    required String taskTitle,
    required Duration duration,
  }) async {
    final code = await LanguageService.loadSelectedLanguageCode();
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    await _plugin.show(
      id,
      _text(code, 'taskTimerStartedTitle'),
      '${_text(code, 'taskTimerStartedBody')}\n${AppTexts.localizeCanonicalTextForCode(code, taskTitle)}\n${_text(code, 'taskTimerDuration')}: ${duration.inMinutes} ${_text(code, 'minutesShort')}.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _taskStartChannelId,
          _text(code, 'channelNameTaskTimerStart'),
          importance: Importance.max,
          visibility: NotificationVisibility.private,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
    );
  }

  static Future<void> showDurationBarrierStartedNotification({
    required String taskTitle,
    required Duration duration,
  }) async {
    final code = await LanguageService.loadSelectedLanguageCode();
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    final durationText = AppTexts.formatAdaptiveDurationPhrase(
      code,
      duration.inMinutes,
    );
    final instruction = _text(
      code,
      'barrierStartedInstruction',
    ).replaceAll('{duration}', durationText);
    await _plugin.show(
      id,
      _text(code, 'barrierStartedTitle'),
      '$instruction\n${AppTexts.localizeCanonicalTextForCode(code, taskTitle)}\n${_text(code, 'barrierStartedDuration')}: $durationText.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _taskStartChannelId,
          _text(code, 'channelNameDurationBarrierCall'),
          importance: Importance.max,
          visibility: NotificationVisibility.private,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
    );
  }

  /// Phase 11: a gentle "get up and move" nudge — deliberately styled like
  /// the breath-test reminder (normal ringtone, no insistent flag, no
  /// full-screen takeover) rather than the alarm-style task notifications,
  /// since this is a wellness suggestion the user can freely ignore, not
  /// something the discipline protocol needs an answer to.
  static Future<void> showSedentaryReminderNotification() async {
    // Lowest priority of anything offered — if the day's budget is spoken
    // for, this is the first thing to give way, and never at the cost of a
    // measurement that cannot be taken again later.
    if (!await _budgetAllows(
      NotificationKind.sedentary,
      lowestPendingOfferedPriority: const NotificationBudget().priorityOf(
        NotificationKind.sedentary,
      ),
    )) {
      return;
    }
    final code = await LanguageService.loadSelectedLanguageCode();
    await _plugin.show(
      _sedentaryReminderNotificationId,
      _text(code, 'sedentaryReminderTitle'),
      _text(code, 'sedentaryReminderBody'),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _sedentaryReminderChannelId,
          _text(code, 'channelNameMovementReminder'),
          importance: Importance.high,
          visibility: NotificationVisibility.private,
          priority: Priority.high,
          playSound: true,
          // Default vibration only (no custom pattern) -- keeps this a
          // gentle nudge rather than the insistent pattern the discipline
          // protocol's task alerts use, while still not being silent.
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
    );
  }

  /// Tells the user a full day has gone by with no breathing test.
  ///
  /// Separate from the daily reminder, which fires at a time of day whether
  /// or not a reading was taken. This one is about the gap itself: the trend
  /// the whole programme reports on is built from these readings, and a
  /// missed day cannot be filled in afterwards.
  ///
  /// A fixed id, so re-showing it replaces the previous one rather than
  /// stacking a fresh copy every time the app is opened.
  static Future<void> showBreathTestOverdueNotification() async {
    final code = await LanguageService.loadSelectedLanguageCode();
    await _plugin.show(
      _breathOverdueNotificationId,
      _text(code, 'dailyBreathOverdueNotificationTitle'),
      _text(code, 'dailyBreathOverdueNotificationBody'),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _sedentaryReminderChannelId,
          _text(code, 'channelNameMovementReminder'),
          importance: Importance.high,
          visibility: NotificationVisibility.private,
          priority: Priority.high,
          playSound: true,
          // A nudge, not a task alert: no insistent flag and no alarm sound,
          // because nothing here is time-critical to the minute.
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
    );
  }

  static Future<void> scheduleCoachCommandNotifications({
    required List<String> commands,
    String? predictedRiskWindow,
    int? maxNotifications,
    int spacingMinutes = 20,
  }) async {
    if (commands.isEmpty) {
      return;
    }

    final scheduleMode = await _resolveAndroidScheduleMode();
    final code = await LanguageService.loadSelectedLanguageCode();
    final now = tz.TZDateTime.now(tz.local);
    final windowStart = _parseWindowStart(predictedRiskWindow);

    var base = _atDeviceTimeOfDay(
      windowStart?.hour ?? now.hour,
      windowStart?.minute ?? now.minute,
    );
    if (!base.isAfter(now)) {
      base = base.add(const Duration(days: 1));
    }

    final firstAt = base.subtract(const Duration(minutes: 30));
    final normalizedFirstAt = firstAt.isAfter(now)
        ? firstAt
        : now.add(const Duration(minutes: 2));
    final interruptionContext = await _resolveInterruptionContext();
    final extraDelay =
        (interruptionContext['recommendedDeferralMinutes'] as int?) ?? 0;
    final contextLabel =
        interruptionContext['contextLabel']?.toString() ?? 'normal';
    final confidence =
        (interruptionContext['confidence'] as num?)?.toDouble() ?? 0.0;
    await _persistNotificationContext(
      code: code,
      contextLabel: contextLabel,
      confidence: confidence,
    );

    final safeSpacing = spacingMinutes < 10 ? 10 : spacingMinutes;
    final configuredMax = (maxNotifications ?? 3).clamp(1, 6);
    final maxCount = commands.length < configuredMax
        ? commands.length
        : configuredMax;
    for (var i = 0; i < maxCount; i++) {
      final fireAt = await _reserveNonConflictingTime(
        normalizedFirstAt
            .add(Duration(minutes: i * safeSpacing))
            .add(Duration(minutes: extraDelay)),
      );
      // A coaching line is offered, not owed: it competes for the same daily
      // slots as the health tip, the breath reminder and the sedentary
      // nudge, and yields to any of them still waiting for one.
      if (!await _budgetAllows(
        NotificationKind.coachCommand,
        at: fireAt,
        lowestPendingOfferedPriority: const NotificationBudget().priorityOf(
          NotificationKind.coachCommand,
        ),
      )) {
        continue;
      }
      final id = (DateTime.now().millisecondsSinceEpoch + 700000 + i).remainder(
        2147483647,
      );

      await _plugin.zonedSchedule(
        id,
        _text(code, 'coachCommandTitle'),
        AppTexts.localizeCanonicalTextForCode(code, commands[i]),
        fireAt,
        NotificationDetails(
          android: AndroidNotificationDetails(
            // A different channel from task alerts on purpose. A coaching
            // line is offered, a task is owed, and using the same alarm
            // sound and full-screen intent for both made every notification
            // in the app look and feel like the one most urgent kind.
            _coachCommandChannelId,
            _text(code, 'channelNameCoachSuggestion'),
            importance: Importance.defaultImportance,
            visibility: NotificationVisibility.private,
            priority: Priority.defaultPriority,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.reminder,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                _actionTaskDone,
                _text(code, 'taskActionDoneLabel'),
                showsUserInterface: false,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                _actionTaskNotNow,
                _text(code, 'taskActionNotNowLabel'),
                showsUserInterface: false,
                cancelNotification: true,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            categoryIdentifier: _categoryTaskStart,
            presentSound: true,
          ),
        ),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode({'type': _typeTaskStart, 'taskTitle': commands[i]}),
      );
    }
  }

  /// Shared cross-scheduler collision avoidance. Health tips, breath
  /// reminders, coach commands, the weekly-survey-due reminder, and
  /// deferred ("not now") task triggers are each scheduled by independent
  /// code paths with no visibility into what the others already scheduled
  /// -- each one already spaces its *own* notifications apart internally,
  /// but nothing previously stopped e.g. a health tip and a breath reminder
  /// from landing in the same minute, which is exactly the "notifications
  /// arrive back to back" complaint a single scheduler's internal spacing
  /// can't fix on its own. This nudges [proposed] forward in [minGap] steps
  /// until it's at least [minGap] from every other still-pending
  /// reservation, then records it so later calls (including from other
  /// scheduler functions) see it too. Deliberately NOT used for medication
  /// reminders (the user chose those exact times for a reason) or the
  /// immediate/urgent task-trigger alerts (those must fire on their own
  /// timing, never pushed later to dodge a reminder).
  /// The one gate every notification passes through.
  ///
  /// Returns false when this one should not be sent. Fifteen schedulers used
  /// to decide for themselves and only three consulted the shared spacing
  /// helper, so each looked correct alone while the person holding the phone
  /// heard from six unrelated code paths in a row. Nothing counted the total
  /// and nothing chose what to drop once the day was full.
  ///
  /// Scheduled notifications are counted when they are scheduled, not when
  /// they fire: the app may not be running at that moment, so there is no
  /// later opportunity to ask.
  static Future<bool> _budgetAllows(
    NotificationKind kind, {
    DateTime? at,
    int lowestPendingOfferedPriority = 99,
  }) async {
    try {
      const budget = NotificationBudget();
      final storage = StorageService();

      // Checked before spending anything from the budget: a kind the user
      // switched off in Settings should not also use up a slot another,
      // wanted kind could have had today.
      if (budget.classOf(kind) == NotificationClass.offered &&
          !await storage.isNotificationKindEnabled(kind.name)) {
        return false;
      }

      final when = at ?? DateTime.now();
      final (sentToday, lastSentAt) = await storage.loadNotificationBudgetState(
        now: when,
      );
      final decision = budget.decide(
        kind: kind,
        at: when,
        intensity: await storage.loadInterventionIntensity(),
        offeredSentToday: sentToday,
        lastSentAt: lastSentAt,
        lowestPendingOfferedPriority: lowestPendingOfferedPriority,
      );
      if (!decision.allowed) {
        return false;
      }
      await storage.recordNotificationSent(
        countsAgainstBudget: budget.classOf(kind) == NotificationClass.offered,
        at: when,
      );
      return true;
    } catch (_) {
      // A failure here must never silence a task the user is owed.
      return true;
    }
  }

  static Future<tz.TZDateTime> _reserveNonConflictingTime(
    tz.TZDateTime proposed, {
    Duration minGap = const Duration(minutes: 25),
  }) async {
    try {
      final storage = StorageService();
      final now = DateTime.now().millisecondsSinceEpoch;
      final raw = await storage.loadSetting(_reservedTimesSettingKey);
      var reserved = <int>[];
      if (raw != null && raw.isNotEmpty) {
        reserved = (jsonDecode(raw) as List)
            .whereType<num>()
            .map((n) => n.toInt())
            .where((millis) => millis > now)
            .toList();
      }

      var candidate = proposed;
      var guard = 0;
      while (guard < 48 &&
          reserved.any(
            (millis) =>
                (candidate.millisecondsSinceEpoch - millis).abs() <
                minGap.inMilliseconds,
          )) {
        candidate = candidate.add(minGap);
        guard++;
      }

      reserved.add(candidate.millisecondsSinceEpoch);
      await storage.saveSetting(_reservedTimesSettingKey, jsonEncode(reserved));
      return candidate;
    } catch (_) {
      return proposed;
    }
  }

  static Future<Map<String, dynamic>> _resolveInterruptionContext() async {
    try {
      return await PhoneStateService().inferRealtimeInterruptionContext();
    } catch (_) {
      return {
        'isDriving': false,
        'isRunningOrWorkout': false,
        'isEatingLikely': false,
        'recommendedDeferralMinutes': 0,
        'confidence': 0.0,
        'contextLabel': 'normal',
      };
    }
  }

  static Future<void> _persistNotificationContext({
    required String code,
    required String contextLabel,
    required double confidence,
  }) async {
    try {
      final storage = StorageService();
      final confidencePct = (confidence * 100).round().clamp(0, 100);
      await storage.saveSetting(
        'last_notification_context_label',
        contextLabel,
      );
      await storage.saveSetting(
        'last_notification_context_confidence',
        confidencePct.toString(),
      );
      await storage.saveSetting(
        'last_notification_context_reason',
        _contextReasonText(code, contextLabel, confidencePct),
      );
    } catch (_) {
      // Best effort only.
    }
  }

  static String _contextReasonText(
    String code,
    String contextLabel,
    int confidencePct,
  ) {
    if (contextLabel == 'driving') {
      return '${_text(code, 'contextReasonDriving')} (%$confidencePct)';
    }
    if (contextLabel == 'workout') {
      return '${_text(code, 'contextReasonWorkout')} (%$confidencePct)';
    }
    if (contextLabel == 'eating') {
      return '${_text(code, 'contextReasonEating')} (%$confidencePct)';
    }
    return _text(code, 'contextReasonNormal');
  }

  static DateTime? _parseWindowStart(String? predictedRiskWindow) {
    if (predictedRiskWindow == null || predictedRiskWindow.trim().isEmpty) {
      return null;
    }

    final first = predictedRiskWindow.split('-').first.trim();
    final parts = first.split(':');
    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  static String _text(String code, String key) {
    return AppTexts.textForCode(code, key);
  }

  static Future<void> showWheezeTestResultAdvisory({
    required bool wheezeDetected,
    required String severityLevel,
  }) async {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      return;
    }

    final body = wheezeDetected
        ? 'Wheeze detected. Severity: $severityLevel'
        : 'No wheeze detected.';

    await navigator.push(
      MaterialPageRoute(builder: (_) => HealthTipPage(body: body)),
    );
  }

  /// Called from main() on cold start.
  ///
  /// When the app was fully terminated and a notification tap launched it,
  /// [onDidReceiveNotificationResponse] may never fire because the isolate
  /// wasn't alive at tap time. This method checks the launch details and
  /// routes to the correct page (or resolves the action silently) so the
  /// user always gets the full-screen experience.
  static Future<void> handleColdStartIfLaunchedFromNotification() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return;
      final response = details?.notificationResponse;
      if (response == null) return;
      // Run after a short delay so the widget tree is built and the
      // navigator is ready to push routes.
      Future.delayed(const Duration(milliseconds: 800), () {
        _handleNotificationResponse(response);
      });
    } catch (_) {
      // Non-blocking: a cold-start route failure must never crash startup.
    }
  }
}
