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
import 'android_watchdog_service.dart';
import 'language_service.dart';
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
          'Gorev erteleme secimi',
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
      payload: jsonEncode({
        'type': _typeTaskPostpone,
        'taskTitle': taskTitle,
      }),
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
          'Gorev sonu onayi',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          sound: _taskAlarmSound,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
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
      payload: jsonEncode({
        'type': _typeTaskConfirm,
        'taskTitle': taskTitle,
      }),
    );
  }

  /// Stable per-task ids so a re-issued prompt replaces its predecessor
  /// instead of stacking a second copy of the same question.
  static int _postponeChoiceIdFor(String taskTitle) =>
      (taskTitle.hashCode.abs() % 100000) + 810000;

  static int _confirmIdFor(String taskTitle) =>
      (taskTitle.hashCode.abs() % 100000) + 820000;

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
  static const String _sedentaryReminderChannelId = 'sedentary_reminder_channel_v1';
  static const int _sedentaryReminderNotificationId = 920001;
  static const int _sleepActivityAdvisoryNotificationId = 930001;
  static const int _weeklySurveyNotificationId = 700001;
  static const int _dailyBreathReminderBaseId = 420100;
  static const int _dailyBreathReminderMaxSlots = 6;
  static const String _healthTipChannelId = 'health_tip_channel_v2';
  static const int _healthTipBaseId = 430100;
  /// Standalone advice notifications a day, for users who take no medication.
  ///
  /// Was three. Everyone with medication now gets their tip folded into a
  /// reminder they already receive, so this path only serves people with a
  /// condition but nothing to take — and for them one a day is a reminder,
  /// three was nagging.
  static const int _healthTipDailyCount = 1;
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
  static const int _healthTipsPerCondition = 30;

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
    await _syncTaskOverlayOutcomesFromNative();
    await _syncSleepActivityFromNative();
    await _syncSmokedLogEventsFromNative();
    await _restoreSmokedLogButton(code);
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
        final closedAssignment = taskTitle != null &&
            await _transitionTask(taskTitle, TaskLifecycleState.failedMissed);

        // Feeds the same "no response" event into the adaptive engine (see
        // AdaptiveTaskOutcome.missed) so difficultyLevel/streak react to it
        // exactly like any other failed task, not just the violation log.
        // Only meaningful for the canonical adaptive-plan task format --
        // other command types (coach commands, etc.) aren't tracked by the
        // adaptive engine at all, so there's nothing to record for those.
        final adaptiveMatch = closedAssignment || taskTitle == null
            ? null
            : RegExp(
                r'^ADAPTIVE_NO_SMOKE:(\d+)$',
              ).firstMatch(taskTitle.trim());
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
      final lastAt = lastAtRaw == null
          ? null
          : DateTime.tryParse(lastAtRaw);
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

  static Future<void> _showSleepActivityAdvisory() async {
    final code = await LanguageService.loadSelectedLanguageCode();
    await _plugin.show(
      _sleepActivityAdvisoryNotificationId,
      _text(code, 'sleepActivityAdvisoryTitle'),
      _text(code, 'sleepActivityAdvisoryBody'),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _healthTipChannelId,
          'Saglik tavsiyesi',
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
      payload: jsonEncode({'type': _typeHealthTip}),
    );
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
        final dynamic requested =
            await androidPlugin.requestFullScreenIntentPermission();
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
    unawaited(
      _processNotificationResponse(response, allowNavigation: false),
    );
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
      // Freshly fetched from the global navigator key (not a captured
      // widget BuildContext held across the gap above), so this is safe
      // despite the preceding await.
      final context = _navigatorKey?.currentContext;
      if (context != null) {
        // ignore: use_build_context_synchronously
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const BreathTestPage()));
      }
      return;
    }

    if (type == _typeWeeklySurvey) {
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
      await _transitionTask(
        canonicalTitle, TaskLifecycleState.accepted);
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
      await _transitionTask(
        canonicalTitle, TaskLifecycleState.failedDeclined);
      return;
    }

    if (actionId == _actionTaskSos) {
      // Suspended, not finished — the breathing exercise runs and hands the
      // user back to this same task afterwards.
      await _transitionTask(
        canonicalTitle, TaskLifecycleState.sosActive);
      _openSosPage(canonicalTitle);
      return;
    }

    // The end-of-window answer. "Did you smoke?" — so yes is the failure.
    // Getting this backwards would invert every outcome the learning engine
    // ever records, which is why these ids are distinct from the older
    // followup pair rather than reused.
    if (actionId == _actionConfirmSmokedYes) {
      await _transitionTask(
        canonicalTitle, TaskLifecycleState.failedSmoked);
      // An admission is also a real cigarette, so it belongs in the same
      // table the quick-log button writes to — otherwise the risky-hour
      // ranking never learns about the ones admitted this way.
      await StorageService().logSmokingNow();
      return;
    }
    if (actionId == _actionConfirmSmokedNo) {
      await _transitionTask(
        canonicalTitle, TaskLifecycleState.succeeded);
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
    final androidCategory = isFollowUp
        ? AndroidNotificationCategory.call
        : AndroidNotificationCategory.reminder;
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
          'Gorev guncelleme hatirlatici',
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
          'İlk görev tetikleme',
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
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
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
    );
    await AndroidWatchdogService.showTaskOverlay(
      title: _text(code, 'disciplineCommand'),
      body: adjustedDescription,
      doneLabel: _text(code, 'taskActionDoneLabel'),
      // Blank when the allowance is spent, so the overlay shows exactly the
      // same answers the notification does.
      postponeLabel: allowance.$1 < maxPostponesPerTask
          ? _text(code, 'taskActionNotNowLabel')
          : '',
      declineLabel: _text(code, 'taskActionDeclineLabel'),
      sosLabel: allowance.$2 < maxSosPerTask
          ? _text(code, 'taskActionSosLabel')
          : '',
      watchdogId: watchdogId,
      taskTitle: taskTitle,
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
    final fireAt = now.add(delay).add(Duration(minutes: extraDelay));
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
          'İlk görev tetikleme',
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
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
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
      doneLabel: _text(code, 'taskActionDoneLabel'),
      // Blank when the allowance is spent, so the overlay shows exactly the
      // same answers the notification does.
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

    final wakeParts = wakeTime.split(':');
    final wakeHour = int.tryParse(wakeParts[0]) ?? 7;
    final wakeMinute = int.tryParse(wakeParts[1]) ?? 0;

    final sleepParts = sleepTime.split(':');
    final sleepHour = int.tryParse(sleepParts[0]) ?? 21;
    final sleepMinute = int.tryParse(sleepParts[1]) ?? 0;

    var wakeAt = _atDeviceTimeOfDay(
      wakeHour,
      wakeMinute,
    );
    var sleepAt = _atDeviceTimeOfDay(
      sleepHour,
      sleepMinute,
    );
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
            'Nefes testi hatırlatıcı',
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
            'Nefes testi hatırlatıcı',
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
    for (var i = 0; i < _healthTipDailyCount; i++) {
      await _plugin.cancel(_healthTipBaseId + i);
    }
    if (healthConditions.isEmpty) {
      return;
    }

    // Anyone with medication already gets their tip attached to a reminder
    // they receive anyway (see scheduleMedicationReminders). Sending this as
    // well would say the same thing twice in one day.
    final takesMedication = (await StorageService().loadMedications()).isNotEmpty;
    if (takesMedication) {
      return;
    }

    final scheduleMode = await _resolveAndroidScheduleMode();
    final code = await LanguageService.loadSelectedLanguageCode();
    final now = tz.TZDateTime.now(tz.local);

    final wakeParts = wakeTime.split(':');
    final wakeHour = int.tryParse(wakeParts[0]) ?? 7;
    final wakeMinute = int.tryParse(wakeParts.length > 1 ? wakeParts[1] : '0') ?? 0;

    final sleepParts = sleepTime.split(':');
    final sleepHour = int.tryParse(sleepParts[0]) ?? 21;
    final sleepMinute = int.tryParse(sleepParts.length > 1 ? sleepParts[1] : '0') ?? 0;

    var wakeAt = _atDeviceTimeOfDay(
      wakeHour,
      wakeMinute,
    );
    var sleepAt = _atDeviceTimeOfDay(
      sleepHour,
      sleepMinute,
    );
    if (!sleepAt.isAfter(wakeAt)) {
      sleepAt = sleepAt.add(const Duration(days: 1));
    }

    final windowMinutes = sleepAt.difference(wakeAt).inMinutes;
    final intervalMinutes = windowMinutes ~/ (_healthTipDailyCount + 1);

    var conditionCursor = 0;
    var variantCursor = 0;
    for (var i = 0; i < _healthTipDailyCount; i++) {
      var fireAt = wakeAt.add(Duration(minutes: intervalMinutes * (i + 1)));
      if (!fireAt.isAfter(now)) {
        fireAt = fireAt.add(const Duration(days: 1));
      }
      fireAt = await _reserveNonConflictingTime(fireAt);

      final condition = healthConditions[conditionCursor % healthConditions.length];
      final prefix = _healthTipPrefixByCondition[condition];
      conditionCursor++;
      if (prefix == null) {
        continue;
      }
      final tipKey = '$prefix${(variantCursor % _healthTipsPerCondition) + 1}';
      variantCursor++;

      await _plugin.zonedSchedule(
        _healthTipBaseId + i,
        _text(code, 'healthTipTitle'),
        '${_text(code, tipKey)}\n${_text(code, 'medicationAdviceDisclaimer')}',
        fireAt,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _healthTipChannelId,
            'Saglik tavsiyesi',
            importance: Importance.max,
            visibility: NotificationVisibility.private,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            vibrationPattern: _taskVibrationPattern,
            fullScreenIntent: true,
            audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: const DarwinNotificationDetails(presentSound: true),
        ),
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode({'type': _typeHealthTip}),
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
        var fireAt = _atDeviceTimeOfDay(
          hour,
          minute,
        );
        if (!fireAt.isAfter(now)) {
          fireAt = fireAt.add(const Duration(days: 1));
        }

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
              'Ilac hatirlatmasi',
              importance: Importance.max,
              visibility: NotificationVisibility.private,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              vibrationPattern: _taskVibrationPattern,
              fullScreenIntent: true,
              audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
              category: AndroidNotificationCategory.reminder,
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
          'Görev takip hatırlatıcı',
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
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
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

    await _plugin.cancel(_weeklySurveyNotificationId);
    await _plugin.zonedSchedule(
      _weeklySurveyNotificationId,
      _text(code, 'weeklySurveyReminderTitle'),
      _text(code, 'weeklySurveyReminderBody'),
      fireAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _weeklySurveyChannelId,
          'Haftalik anket hatirlatici',
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
          'Task timer start',
          importance: Importance.max,
          visibility: NotificationVisibility.private,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          // fullScreenIntent (not the alarm sound/insistent-loop combo the
          // actual task-trigger alert uses) is enough to make this land as
          // a large, hard-to-miss banner — this fires right after the user
          // already said yes to a task, so it should be clearly visible,
          // not urgently repeating.
          fullScreenIntent: true,
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
    final instruction = code == 'tr'
        ? 'Lütfen önümüzdeki $durationText boyunca sigara içmeyin. Elinizde sigara varsa hemen söndürün.'
        : 'Please do not smoke for the next $durationText. If you have a cigarette in your hand, put it out now.';
    await _plugin.show(
      id,
      _text(code, 'barrierStartedTitle'),
      '$instruction\n${AppTexts.localizeCanonicalTextForCode(code, taskTitle)}\n${_text(code, 'barrierStartedDuration')}: $durationText.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _taskStartChannelId,
          'Duration barrier call',
          importance: Importance.max,
          visibility: NotificationVisibility.private,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
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
    final code = await LanguageService.loadSelectedLanguageCode();
    await _plugin.show(
      _sedentaryReminderNotificationId,
      _text(code, 'sedentaryReminderTitle'),
      _text(code, 'sedentaryReminderBody'),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _sedentaryReminderChannelId,
          'Hareket hatırlatıcı',
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
        iOS: DarwinNotificationDetails(presentSound: true),
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
    final maxCount = commands.length < configuredMax ? commands.length : configuredMax;
    for (var i = 0; i < maxCount; i++) {
      final fireAt = await _reserveNonConflictingTime(
        normalizedFirstAt
            .add(Duration(minutes: i * safeSpacing))
            .add(Duration(minutes: extraDelay)),
      );
      final id =
          (DateTime.now().millisecondsSinceEpoch + 700000 + i).remainder(
            2147483647,
          );

      await _plugin.zonedSchedule(
        id,
        'Kisisel Komut',
        commands[i],
        fireAt,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _taskStartChannelId,
            'Kisisel komut bildirimi',
            importance: Importance.max,
            visibility: NotificationVisibility.private,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            vibrationPattern: _taskVibrationPattern,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            category: AndroidNotificationCategory.call,
            fullScreenIntent: true,
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
        payload: jsonEncode({
          'type': _typeTaskStart,
          'taskTitle': commands[i],
        }),
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
      await storage.saveSetting(
        _reservedTimesSettingKey,
        jsonEncode(reserved),
      );
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
      await storage.saveSetting('last_notification_context_label', contextLabel);
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
}
