import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
import '../pages/notifications_page.dart';
import '../widgets/daily_progress_report_view.dart';
import '../pages/weekly_survey_page.dart';
import 'android_watchdog_service.dart';
import 'behavior_engine.dart';
import 'language_service.dart';
import 'notification_budget.dart';
import 'notification_history_service.dart';
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
  // Signals a task-start notification body-tap to HomePage rather than
  // pushing MandatoryTaskPage directly from here — HomePage's own
  // _presentMandatoryTaskIfNeeded also opens that page on its own lifecycle
  // (resume/foreground), and two independent pushes racing each other left
  // the tap sometimes doing nothing the user could see (see WORK_LIST.md).
  // A single always-wins source (HomePage, told to skip its own cooldown)
  // replaces both.
  static final StreamController<void> _mandatoryTaskRequestController =
      StreamController<void>.broadcast();
  static GlobalKey<NavigatorState>? _navigatorKey;

  static void _pushNotificationRoute(Widget page) {
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  /// Records a notification in the history for the Notifications page.
  /// Called after every notification is shown.
  static void _recordNotificationHistory({
    required String title,
    required String body,
    required String type,
    String? dedupeKey,
    DateTime? receivedAt,
    DateTime? availableAt,
  }) {
    unawaited(
      NotificationHistoryService.record(
        title: title,
        body: body,
        type: type,
        dedupeKey: dedupeKey,
        receivedAt: receivedAt,
        availableAt: availableAt,
      ),
    );
  }

  static Future<void> _show(
    int id,
    String? title,
    String? body,
    NotificationDetails details, {
    String? payload,
  }) async {
    await _plugin.show(id, title, body, details, payload: payload);
    _recordNotificationHistory(
      title: title ?? '',
      body: body ?? '',
      type: _historyTypeFromPayload(payload),
      dedupeKey: _historyDedupeKey(
        title: title ?? '',
        body: body ?? '',
        payload: payload,
      ),
    );
  }

  static Future<void> _zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails details, {
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
    required UILocalNotificationDateInterpretation
    uiLocalNotificationDateInterpretation,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: androidScheduleMode,
      payload: payload,
      uiLocalNotificationDateInterpretation:
          uiLocalNotificationDateInterpretation,
      matchDateTimeComponents: matchDateTimeComponents,
    );
    _recordNotificationHistory(
      title: title ?? '',
      body: body ?? '',
      type: _historyTypeFromPayload(payload),
      dedupeKey: _historyDedupeKey(
        title: title ?? '',
        body: body ?? '',
        payload: payload,
      ),
      receivedAt: scheduledDate,
      availableAt: scheduledDate,
    );
  }

  static String? _historyDedupeKey({
    required String title,
    required String body,
    required String? payload,
  }) {
    final type = _historyTypeFromPayload(payload);
    if (payload != null && payload.isNotEmpty) {
      try {
        final data = jsonDecode(payload);
        if (data is Map<String, dynamic>) {
          final notificationId = data['notificationId'];
          if (notificationId is String && notificationId.isNotEmpty) {
            return '$type:$notificationId';
          }
        }
      } catch (_) {
        // Fall back to the stable visible content below.
      }
    }
    if (title.isEmpty && body.isEmpty) return null;
    return '$type:$title:$body';
  }

  static String _historyTypeFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return 'general';
    try {
      final type = (jsonDecode(payload) as Map<String, dynamic>)['type'];
      return type is String && type.isNotEmpty ? type : 'general';
    } catch (_) {
      return 'general';
    }
  }

  static const String _typeBreath = 'breath';
  static const String _typeTaskStart = 'task_start';
  static const String _typeTaskFollowUp = 'task_followup';
  static const String _typeTaskPostpone = 'task_postpone';
  static const String _typeTaskConfirm = 'task_confirm';
  static const String _typeWeeklySurvey = 'weekly_survey';
  static const String _typeHealthTip = 'health_tip';
  static const String _typeMedicationReminder = 'medication_reminder';
  static const String _typeSleepReport = 'sleep_report';
  static const int _sleepReportNotificationId = 1600001;
  static const String _sleepReportChannelId = 'sleep_report_channel_v1';

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
  static const String _taskConfirmChannelId = 'task_confirm_channel_v2';

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

  /// Reads how much of a task's postpone/SOS allowance is already spent.
  ///
  /// Returns zeroes for anything without a row — tasks issued before the
  /// assignments table existed, and the very first prompt of a new one.
  /// Public so [MandatoryTaskPage] can show/hide its own Ertele/SOS buttons
  /// with the same limits the (now action-less) notification used to.
  static Future<(int postponeCount, int sosCount)> taskAllowanceFor(
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

    await _show(
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
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionPostpone10,
              _text(code, 'postpone10Label'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionPostpone15,
              _text(code, 'postpone15Label'),
              showsUserInterface: true,
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
    // Owed, so always allowed — recorded so offered notifications' spacing
    // check knows this moment is taken.
    await _budgetAllows(NotificationKind.taskConfirmation, at: fireAt);

    await _zonedSchedule(
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
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionConfirmSmokedNo,
              _text(code, 'taskConfirmNoLabel'),
              showsUserInterface: true,
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

  /// Schedules the automated morning Sleep Intelligence report one hour after
  /// the planned wake-up time. A single stable id means the latest evening
  /// answer replaces an older plan instead of stacking duplicate reports.
  static Future<void> scheduleSleepReportNotification({
    required DateTime wakeAt,
  }) async {
    final code = await LanguageService.loadSelectedLanguageCode();
    final scheduleMode = await _resolveAndroidScheduleMode();
    final fireAt = tz.TZDateTime.from(
      wakeAt.add(const Duration(hours: 1)),
      tz.local,
    );
    if (!fireAt.isAfter(tz.TZDateTime.now(tz.local))) {
      return;
    }
    await _plugin.cancel(_sleepReportNotificationId);
    await _zonedSchedule(
      _sleepReportNotificationId,
      _text(code, 'sleepRoutineReportTitle'),
      _text(code, 'sleepRoutineCommand'),
      fireAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _sleepReportChannelId,
          _text(code, 'sleepRoutineReportTitle'),
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.private,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': _typeSleepReport,
        'notificationId': '$_sleepReportNotificationId',
        'reportDate': wakeAt.toIso8601String(),
      }),
    );
  }

  static const int _wakeAlarmBaseId = 1601000;

  /// Schedules a user-approved wake alarm for one concrete calendar date.
  /// Date-based ids let the weekly schedule be replaced without stacking alarms.
  static Future<void> scheduleWakeAlarmNotification({
    required DateTime wakeAt,
    required int weekday,
  }) async {
    final code = await LanguageService.loadSelectedLanguageCode();
    final fireAt = tz.TZDateTime.from(wakeAt, tz.local);
    if (!fireAt.isAfter(tz.TZDateTime.now(tz.local))) return;
    final id = _wakeAlarmBaseId + weekday;
    await _plugin.cancel(id);
    await _zonedSchedule(
      id,
      _text(code, 'wakeAlarmTitle'),
      _text(code, 'wakeAlarmBody'),
      fireAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'wake_alarm_channel_v1',
          _text(code, 'wakeTime'),
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          sound: _taskAlarmSound,
          additionalFlags: _insistentFlag,
          autoCancel: false,
          ongoing: true,
          onlyAlertOnce: false,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
      androidScheduleMode: await _resolveAndroidScheduleMode(),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': 'wake_alarm',
        'notificationId': '$id',
        'wakeAt': wakeAt.toIso8601String(),
      }),
    );
  }

  static Future<void> cancelWakeAlarmNotification({required int weekday}) async {
    await _plugin.cancel(_wakeAlarmBaseId + weekday);
  }

  static Future<void> cancelAllWakeAlarmNotifications() async {
    for (var weekday = 1; weekday <= 7; weekday++) {
      await cancelWakeAlarmNotification(weekday: weekday);
    }
  }

  static Future<void> cancelSleepReportNotification() async {
    await _plugin.cancel(_sleepReportNotificationId);
  }

  /// Stable per-task ids so a re-issued prompt replaces its predecessor
  /// instead of stacking a second copy of the same question.
  ///
  /// Each function's output range is a full, non-overlapping 100000-wide
  /// block (base offsets exactly 100000 apart, matching the `% 100000`
  /// modulus) so two different task titles can never collide *across*
  /// functions — with the old 810000/820000/850000 offsets (only
  /// 10000-40000 apart, inside the same 100000-wide modulus space), it was
  /// arithmetically possible for e.g. _postponeChoiceIdFor(titleA) to equal
  /// _confirmIdFor(titleB) for some titleA != titleB, which would let
  /// resolving one task's barrier (cancelBarrierResolutionReminder cancels
  /// by these ids) silently cancel a different, unrelated task's still
  /// -pending confirmation prompt. Placed at 1100000+ to stay clear of the
  /// fixed single ids in the 920000s/930000s used elsewhere in this file.
  static int _postponeChoiceIdFor(String taskTitle) =>
      (taskTitle.hashCode.abs() % 100000) + 1100000;

  static int _confirmIdFor(String taskTitle) =>
      (taskTitle.hashCode.abs() % 100000) + 1200000;

  static int _barrierResolutionReminderIdFor(String taskTitle) =>
      (taskTitle.hashCode.abs() % 100000) + 1300000;

  /// A quieter repeat of [scheduleTaskConfirmationPrompt], fired
  /// [barrierResolutionDeadline] after the first prompt in case it never
  /// gets answered. Needs its own notification id — reusing
  /// [_confirmIdFor]'s id would schedule it for the exact same instant as
  /// the first prompt, replacing it outright instead of adding a later
  /// reminder. The delay is deliberately kept in step with
  /// [StorageService.closeStaleAcceptedBarriers]'s own cutoff math (see its
  /// doc comment), which is what gives up on the barrier and closes it as
  /// unknown once the deadline passes.
  static Future<void> scheduleBarrierResolutionReminder({
    required String taskTitle,
    required Duration delay,
  }) async {
    final code = await LanguageService.loadSelectedLanguageCode();
    final scheduleMode = await _resolveAndroidScheduleMode();
    final fireAt = tz.TZDateTime.now(
      tz.local,
    ).add(delay + barrierResolutionDeadline);
    await _budgetAllows(NotificationKind.taskConfirmation, at: fireAt);

    await _zonedSchedule(
      _barrierResolutionReminderIdFor(taskTitle),
      _text(code, 'taskConfirmQuestionTitle'),
      _text(code, 'taskConfirmQuestion'),
      fireAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _taskConfirmChannelId,
          _text(code, 'channelNameTaskConfirm'),
          importance: Importance.high,
          priority: Priority.defaultPriority,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.private,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              _actionConfirmSmokedYes,
              _text(code, 'taskConfirmYesLabel'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionConfirmSmokedNo,
              _text(code, 'taskConfirmNoLabel'),
              showsUserInterface: true,
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

  /// Cancels a previously scheduled barrier-resolution prompt, along with
  /// the first task-confirmation prompt it repeats — both ask the same
  /// question and only one should remain outstanding once the barrier
  /// resolves.
  static Future<void> cancelBarrierResolutionReminder(String taskTitle) async {
    await _plugin.cancel(_confirmIdFor(taskTitle));
    await _plugin.cancel(_barrierResolutionReminderIdFor(taskTitle));
  }

  /// Cancels every scheduled/shown notification of any kind, regardless of
  /// id. Used by Settings' Reset Data and Delete Account flows — those wipe
  /// the sqlite database wholesale, and a still-armed OS alarm (e.g. a
  /// daily-recurring medication reminder) firing afterward would write a
  /// fresh row (dose log, protocol violation) referencing an id that no
  /// longer exists in the just-cleared tables, undermining the "blank
  /// slate" the user asked for. Every other cancel* function in this file
  /// is deliberately narrow (one task, one medication); this is the one
  /// place a blanket cancel is actually correct.
  static Future<void> cancelAll() => _plugin.cancelAll();

  /// Silences whichever task-trigger notification is currently sounding —
  /// its alarm-stream sound/vibration loops via FLAG_INSISTENT until the
  /// notification itself is cancelled (see scheduleFirstTaskTriggerNotification).
  /// Cancelling the notification the user actually tapped already stops it
  /// (see _processNotificationResponse), but MandatoryTaskPage can also be
  /// reached without ever tapping the notification — home_page.dart's
  /// _presentMandatoryTaskIfNeeded opens it on its own the next time the app
  /// is foregrounded, so the alarm kept sounding underneath the page with
  /// nothing to stop it. scheduleFirstTaskTriggerNotification's id is a
  /// throwaway millisecond timestamp with no stored reference to look it up
  /// by, so this queries Android directly for whatever's actually showing
  /// on the task-start channel right now instead.
  static Future<void> cancelActiveTaskTriggerAlarm() async {
    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final active = await androidPlugin?.getActiveNotifications() ?? [];
      for (final notification in active) {
        if (notification.channelId != _taskStartChannelId) continue;
        final id = notification.id;
        if (id == null) continue;
        await _plugin.cancel(id);
      }
    } catch (_) {
      // Best-effort: worst case the alarm keeps sounding until its own
      // timeoutAfter elapses, same as before this existed.
    }
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
  static const String _taskStartChannelId = 'task_start_channel_v8';
  // Separate from _taskStartChannelId: this fires right after the user has
  // already answered the alarm-sound prompt (tapped "Kabul Et"), so it only
  // needs a normal notification tone, not another alarm-stream sound.
  static const String _taskTimerStartedChannelId =
      'task_timer_started_channel_v1';
  static const String _taskFollowUpChannelId = 'task_followup_channel_v8';
  static const String _taskEscalationChannelId = 'task_escalation_channel_v3';
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
  static const String _healthTipChannelId = 'health_tip_channel_v3';
  static const int _healthTipBaseId = 430100;

  /// Keep cancelling the legacy 30-slot range during migration so an upgrade
  // cannot leave old recurring health-tip alarms behind.
  static const int _healthTipLegacySlotCount = 30;
  static const int _healthTipUserMaxCount = 15;
  static const int _healthTipGeneralCount = 7;

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
      'medication_reminder_channel_v3';
  static const int _medicationReminderBaseId = 440100;
  static const int _medicationReminderMaxSlots = 30;

  // scheduleCoachCommandNotifications schedules at most 6 per call
  // (configuredMax is clamped to 1-6) — a fixed slot range lets each call
  // cancel exactly its own previous batch before scheduling a new one,
  // instead of the old millisecondsSinceEpoch-derived id, which was
  // different every call and left the prior batch's still-pending
  // notifications stacking up alongside the new one whenever the coach
  // command signature legitimately changed partway through the same day.
  static const int _coachCommandBaseId = 460100;
  static const int _coachCommandMaxSlots = 6;

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
  static const int _healthTipsGeneralCount = 5;
  static const int _healthTipsSmokingCount = 15;
  static const int _healthTipsGeneralDiseaseCount = 10;

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

  // Mandatory task and medication alerts remain visible until the user acts.
  // Their explicit action buttons and body taps cancel them; no timeout is
  // applied to these attention-critical channels.
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
      RawResourceAndroidNotificationSound('task_alarm');

  static Stream<Map<String, String>> get taskActionStream =>
      _taskActionController.stream;

  static Stream<void> get mandatoryTaskRequestStream =>
      _mandatoryTaskRequestController.stream;

  // Set once _plugin.initialize() has actually run. refreshLocalizedResources
  // (called from splash/settings/language-selection on every single app
  // launch, not just a language change) used to call this same initialize()
  // again, which called _plugin.initialize() a second time moments after
  // main()'s first call — flutter_local_notifications does not re-attach
  // onDidReceiveNotificationResponse cleanly on a repeat call, so the
  // notification body-tap handler silently stopped firing. Proven via
  // logcat: no _processNotificationResponse activity at all on tap, not
  // even a failed attempt. This guard keeps _plugin.initialize() to once
  // per process while still letting the rest of this method's localized
  // resource sync re-run on every call.
  static bool _pluginInitialized = false;

  static Future<void> initialize({
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;
    final code = await LanguageService.loadSelectedLanguageCode();
    tz.initializeTimeZones();
    await _ensureLocalTimeZoneSet();
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
    if (!_pluginInitialized) {
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      _pluginInitialized = true;

      // A notification tap that launches a terminated Flutter process is not
      // delivered through onDidReceiveNotificationResponse. Read the launch
      // details once, otherwise Android brings MainActivity to the foreground
      // but the mandatory task page is never requested and the watchdog later
      // reports an unanswered task.
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      final launchResponse = launchDetails?.notificationResponse;
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchResponse != null) {
        _handleNotificationResponse(launchResponse);
      }
    }

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

  /// Drains native quick-log events when the already-running app resumes.
  /// Cold starts call the private initializer path above; resume needs an
  /// explicit public entry point so the HomePage can then consume its route.
  static Future<void> syncSmokedLogEventsFromNative() {
    return _syncSmokedLogEventsFromNative();
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

  /// Shows a short, gentle morning Sleep Intelligence summary once per day.
  /// The overnight sound signal is only one input to this summary; this is
  /// not presented as a separate medical or snoring test.
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
        final severityKey = switch (tier) {
          'mild' => 'snoringSeverityMild',
          'moderate' => 'snoringSeverityModerate',
          'severe' => 'snoringSeveritySevere',
          _ => 'snoringSeverityNone',
        };
        final adviceKey = switch (tier) {
          'mild' => 'snoringAdviceMild',
          'moderate' => 'snoringAdviceModerate',
          'severe' => 'snoringAdviceSevere',
          _ => null,
        };
        body = _text(code, severityKey);
        if (adviceKey != null) {
          body = '$body\n\n${_text(code, adviceKey)}';
        }
      } else {
        body = _text(code, 'snoringSeverityNone');
      }

      await _show(
        _snoringResultNotificationId,
        _text(code, 'sleepIntelligenceTitle'),
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _healthTipChannelId,
            _text(code, 'channelNameHealthTip'),
            importance: Importance.defaultImportance,
            visibility: NotificationVisibility.private,
            priority: Priority.defaultPriority,
            playSound: true,
            enableVibration: false,
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

      await _show(
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
            enableVibration: false,
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
    await _show(
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
          enableVibration: false,
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
        // "Did you smoke?" answers are a separate vocabulary and route to
        // _typeTaskConfirm — mixing them into the task-start switch below
        // would mis-map a smoked/not-smoked answer onto accept/decline and
        // invert what the learning engine records.
        if (outcome == 'smoked_yes' || outcome == 'smoked_no') {
          _dispatchTaskAction({
            'type': _typeTaskConfirm,
            'taskTitle': taskTitle,
            'canonicalTitle': taskTitle,
            'actionId': outcome == 'smoked_yes'
                ? _actionConfirmSmokedYes
                : _actionConfirmSmokedNo,
          });
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

  /// Returns true when the permission was already granted before this call
  /// — in that case requestExactAlarmsPermission() completes without ever
  /// opening a settings screen, which the caller needs to know so it can
  /// tell the user "already on" instead of leaving a tap that visibly does
  /// nothing.
  static Future<bool> openExactAlarmSettingsOptional() async {
    try {
      final dynamic androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin == null) {
        return false;
      }
      final dynamic alreadyGranted = await androidPlugin
          .canScheduleExactNotifications();
      if (alreadyGranted == true) {
        return true;
      }
      await androidPlugin.requestExactAlarmsPermission();
      return false;
    } catch (_) {
      // Optional action: ignore on unsupported devices/APIs.
      return false;
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

  static Future<void> _openHistoryBeforeOverlay(bool allowNavigation) async {
    if (!allowNavigation) return;
    _pushNotificationRoute(const NotificationsPage());
    await Future<void>.delayed(const Duration(milliseconds: 250));
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

    // Cancel the notification that was actually tapped, plus its linked
    // retry reminder. Task-start notifications use different IDs for the
    // visible prompt and the next retry, so cancelling only reminderId can
    // leave the alarm sound running on the tapped notification.
    final notificationIds = <int>{};
    for (final key in ['notificationId', 'reminderId']) {
      final id = int.tryParse(payload[key] ?? '');
      if (id != null) {
        notificationIds.add(id);
      }
    }
    for (final id in notificationIds) {
      unawaited(_plugin.cancel(id));
    }
    final type = payload['type'];

    final code = await LanguageService.loadSelectedLanguageCode();

    // Every notification body tap opens the app and presents the relevant
    // content full-screen. This avoids landing on whichever Flutter page was
    // previously visible.
    if (type == 'notifications') {
      await _openHistoryBeforeOverlay(allowNavigation);
      await AndroidWatchdogService.showInfoOverlayFromNotification(
        title: _text(code, 'notificationsPageTitle'),
        body: payload['body'] ?? _text(code, 'notificationsEmpty'),
        dismissLabel: _text(code, 'doneShort'),
      );
      return;
    }

    if (type == _typeSleepReport) {
      if (allowNavigation) {
        _pushNotificationRoute(
          DailyProgressReportView(
            storageService: StorageService(),
            onClose: () {
              _navigatorKey?.currentState?.pop();
            },
          ),
        );
        return;
      }
      final report = await StorageService().buildDailyProgressReport();
      final body = [
        'Bugün içilen sigara: ${report.todaySmokedCount}',
        'Son 7 gün görev başarısı: ${(report.taskSuccessRateLast7Days * 100).round()}%',
        'Mevcut hedef aralığı: ${report.currentBarrierMinutes} dakika',
        if (report.breathTrend != null && report.breathTrend!.isNotEmpty)
          'Nefes eğilimi: ${report.breathTrend}',
      ].join('\n');
      await AndroidWatchdogService.showInfoOverlayFromNotification(
        title: _text(code, 'sleepRoutineReportTitle'),
        body: body,
        dismissLabel: _text(code, 'doneShort'),
      );
      return;
    }

    if (type == _typeBreath) {
      await _openHistoryBeforeOverlay(allowNavigation);
      await AndroidWatchdogService.showInfoOverlayFromNotification(
        title: _text(code, 'breathReminderTitle'),
        body: payload['body'] ?? _text(code, 'breathReminderBody'),
        dismissLabel: _text(code, 'doneShort'),
      );
      return;
    }

    if (type == _typeWeeklySurvey) {
      await _openHistoryBeforeOverlay(allowNavigation);
      await AndroidWatchdogService.showInfoOverlayFromNotification(
        title: _text(code, 'weeklySurvey'),
        body: payload['body'] ?? _text(code, 'weeklySurveyPromptAsk'),
        dismissLabel: _text(code, 'doneShort'),
      );
      return;
    }

    if (type == _typeMedicationReminder) {
      final actionId = response.actionId ?? '';
      if (actionId.isEmpty) {
        await _openHistoryBeforeOverlay(allowNavigation);
        final medicationName = payload['medicationName'] ?? '';
        await AndroidWatchdogService.showInfoOverlayFromNotification(
          title: _text(code, 'medicationReminderTitle'),
          body: _text(
            code,
            'medicationReminderBody',
          ).replaceAll('{name}', medicationName),
          dismissLabel: _text(code, 'doneShort'),
        );
        return;
      }
      await handleMedicationReminderAction(
        actionId: actionId,
        medicationId: payload['medicationId'] ?? '',
        medicationName: payload['medicationName'] ?? '',
      );
      await AndroidWatchdogService.showInfoOverlayFromNotification(
        title: _text(code, 'medicationReminderTitle'),
        body: _text(code, 'medicationReminderBody').replaceAll(
          '{name}',
          payload['medicationName'] ?? '',
        ),
        dismissLabel: _text(code, 'doneShort'),
      );
      return;
    }

    if (type == _typeHealthTip) {
      await _openHistoryBeforeOverlay(allowNavigation);
      final notificationId = payload['notificationId']?.trim() ?? '';
      await AndroidWatchdogService.showInfoOverlayFromNotification(
        title: payload['title'] ?? _text(code, 'healthTipTitle'),
        body: payload['body'] ?? '',
        dismissLabel: _text(code, 'doneShort'),
      );
      if (notificationId.isNotEmpty) {
        await NotificationHistoryService.markAcknowledged(
          dedupeKey: '$_typeHealthTip:$notificationId',
        );
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
        await _openHistoryBeforeOverlay(allowNavigation);
        // Must offer the real Evet/Hayır answer, not just an acknowledgment
        // — this notification asks a question the user still has to answer,
        // same as tapping one of its own action buttons would.
        await AndroidWatchdogService.showConfirmOverlayFromNotification(
          title: _text(code, 'taskConfirmQuestionTitle'),
          body: _text(code, 'taskConfirmQuestion'),
          yesLabel: _text(code, 'taskConfirmYesLabel'),
          noLabel: _text(code, 'taskConfirmNoLabel'),
          taskTitle: canonicalTitle,
        );
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

      final actionId = response.actionId ?? '';
      if (actionId.isEmpty) {
        // Persist before trying to notify HomePage. The broadcast stream below
        // is only an acceleration path; during a cold start SplashPage may
        // still be routing and there may be no listener yet.
        await StorageService().savePendingMandatoryTask(
          taskTitle: payload['taskTitle'] ?? '',
          canonicalTitle: payload['canonicalTitle'] ?? payload['taskTitle'] ?? '',
          watchdogId: watchdogId,
          notificationId: payload['notificationId'],
        );
        // A body tap brings the app to the foreground (cold start shows the
        // regular home screen first) and shows MandatoryTaskPage on top of
        // it, in-app, rather than the old cross-app WindowManager overlay.
        // This signals HomePage to show it via its own
        // _presentMandatoryTaskIfNeeded rather than pushing the route
        // directly from here: HomePage's resume/foreground lifecycle also
        // calls that same method independently, and two unrelated pushes
        // racing each other left the tap sometimes doing nothing visible —
        // routing both through one path removes the race. Whether the page
        // was accepted is recorded by MandatoryTaskPage's own caller in
        // HomePage, same as every other route into it.
        //
        // HomePage's listener isn't guaranteed to exist yet the instant this
        // runs — a cold/backgrounded app brought to the foreground by the
        // tap needs its widget tree built first, and this callback can beat
        // that. A single retry loop covers the gap instead of the signal
        // silently vanishing into a broadcast stream with nobody listening.
        var attempts = 0;
        while (!_mandatoryTaskRequestController.hasListener && attempts < 10) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          attempts++;
        }
        if (_mandatoryTaskRequestController.hasListener) {
          _mandatoryTaskRequestController.add(null);
        }
        return;
      }

      final event = {
        'type': type ?? '',
        'taskTitle': payload['taskTitle'] ?? '',
        // Falls back to taskTitle for notifications scheduled before this
        // field existed — they'll simply not resolve to a row, which is the
        // same as the behaviour they already had.
        'canonicalTitle':
            payload['canonicalTitle'] ?? payload['taskTitle'] ?? '',
        'actionId': actionId,
      };

      _dispatchTaskAction(event);
      // Action buttons are configured with showsUserInterface=true. Also show
      // a native overlay after the action is dispatched, including on a cold
      // start where HomePage may not yet have subscribed to the stream.
      await AndroidWatchdogService.showInfoOverlayFromNotification(
        title: _text(code, 'disciplineCommand'),
        body: AppTexts.localizeCanonicalTextForCode(
          code,
          payload['taskTitle'] ?? _text(code, 'disciplineCommandBody'),
        ),
        dismissLabel: _text(code, 'doneShort'),
      );
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
  static Future<void> _ensureIsolateReady() async {
    tz.initializeTimeZones();
    await _ensureLocalTimeZoneSet();
  }

  /// Points `tz.local` at the device's actual IANA zone instead of leaving
  /// it at the `timezone` package's own UTC default. Without this,
  /// `matchDateTimeComponents: DateTimeComponents.time` (every repeating
  /// notification — daily breath/medication/health-tip reminders) tells the
  /// plugin to repeat at the same wall-clock time *in tz.local*, which is
  /// UTC, not the device's zone: a user in a DST-observing zone gets every
  /// repeating reminder shifted by exactly the DST offset (usually 1 hour)
  /// twice a year, at each transition. One-shot scheduling
  /// (`_atDeviceTimeOfDay`) sidesteps this by converting a plain local
  /// `DateTime` straight to an absolute instant, which doesn't need a zone
  /// name — but a *repeating* schedule has to recompute its next occurrence
  /// across zone transitions, which needs the real zone. Best-effort and
  /// idempotent: `setLocalLocation` after the first successful call is a
  /// cheap no-op, and if the platform lookup fails, `tz.local` simply stays
  /// at its UTC default — the same behavior as before this fix, not worse.
  static Future<void> _ensureLocalTimeZoneSet() async {
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (error, stackTrace) {
      debugPrint(
        '[NotificationService] Could not resolve device timezone: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
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

  /// Records the end-of-window answer, taken directly from the
  /// notification's own Evet/Hayır action buttons (both the first prompt and
  /// [scheduleBarrierResolutionReminder]'s later repeat share the same
  /// payload type and route here). "Did you smoke?" — so yes is the
  /// failure. Getting this backwards would invert every outcome the
  /// learning engine ever records.
  static Future<void> _resolveTaskConfirmOutcome(
    String canonicalTitle, {
    required bool smoked,
  }) async {
    // The question has now been answered — cancel whichever of the two
    // prompts (first or reminder) didn't fire yet, or it would ask again for
    // a window that's already resolved.
    await cancelBarrierResolutionReminder(canonicalTitle);
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
    await _ensureIsolateReady();

    final storage = StorageService();
    final now = DateTime.now();

    if (actionId == _actionTaskDone) {
      final delay = _resolveInitialTaskDelay(canonicalTitle);
      // Mirrors what HomePage's foreground handler persists, so a task
      // accepted with the app closed leaves the same trail as one accepted
      // with it open.
      await storage.saveTaskResult(
        taskTitle: canonicalTitle,
        taskResult: 'started',
        completedAt: now,
      );
      await storage.saveTaskFollowUp(
        taskTitle: canonicalTitle,
        scheduledAt: now.add(delay),
      );
      await _transitionTask(canonicalTitle, TaskLifecycleState.accepted);
      // The end-of-window question, asked as "did you smoke?". Replaces the
      // old follow-up, which asked whether the task was completed — the same
      // moment, the opposite polarity.
      await scheduleTaskConfirmationPrompt(
        taskTitle: canonicalTitle,
        delay: delay,
      );
      // A quieter repeat if the first prompt never gets answered — mirrors
      // TaskAssignmentService.handleTaskAction's own acceptance branch. This
      // path (app closed/backgrounded) is most task acceptances in practice,
      // so omitting it here would leave the safety-net reminder missing for
      // the majority case even after the foreground path schedules it.
      await scheduleBarrierResolutionReminder(
        taskTitle: canonicalTitle,
        delay: delay,
      );
      return;
    }

    // "Ertele" asks how long rather than picking for the user.
    if (actionId == _actionTaskNotNow) {
      await showPostponeChoiceNotification(taskTitle: canonicalTitle);
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
        taskDescription: canonicalTitle,
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
        taskTitle: canonicalTitle,
        outcome: AdaptiveTaskOutcome.success,
        plannedDurationMinutes: _resolveInitialTaskDelay(
          canonicalTitle,
        ).inMinutes,
        respondedAt: now,
      );
      await storage.saveTaskResult(
        taskTitle: canonicalTitle,
        taskResult: 'willpower_success',
        completedAt: now,
      );
      await storage.resolveTaskFollowUpByTitle(canonicalTitle);
      return;
    }

    if (actionId == _actionFollowUpLater || actionId == _actionSmokedNo) {
      await scheduleTaskFollowUpReminder(
        taskTitle: canonicalTitle,
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
    await _ensureIsolateReady();
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

  /// Cancels a pending postpone-reminder for one medication, if any is
  /// outstanding. [scheduleMedicationReminders] only ever cancels its own
  /// fixed recurring-slot id range (see the comment on
  /// _scheduleMedicationPostponeReminder's id) so it can never reach this
  /// one — deleting a medication, or saving an edit to it (which reuses the
  /// same id), must call this separately or a "postponed" reminder for it
  /// keeps firing after the medication is gone or renamed.
  static Future<void> cancelMedicationPostponeReminder(
    String medicationId,
  ) async {
    await _plugin.cancel(
      _medicationReminderBaseId +
          _medicationReminderMaxSlots +
          (medicationId.hashCode.abs() % 10000),
    );
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
    // Owed, so always allowed — recorded so offered notifications' spacing
    // check knows this moment is taken.
    await _budgetAllows(NotificationKind.medication, at: fireAt);

    await _zonedSchedule(
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
          sound: _taskAlarmSound,
          additionalFlags: _insistentFlag,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: AndroidNotificationCategory.reminder,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              _actionMedicationTaken,
              _text(code, 'taskActionDoneLabel'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionMedicationPostpone,
              _text(code, 'taskActionNotNowLabel'),
              showsUserInterface: true,
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
    // The task-trigger retry (isFollowUp == false) drops the task detail from
    // the body for the same reason showFirstTaskTriggerNotification does —
    // it's a repeat of that same alarm, answerable only by opening
    // MandatoryTaskPage. The older task_followups retry is untouched.
    final body = isFollowUp
        ? '${_text(code, 'taskFollowUpQuestion')}\n${AppTexts.localizeCanonicalTextForCode(code, taskTitle)}'
        : _text(code, 'taskEscalationBodyPrefix');
    final androidCategory = AndroidNotificationCategory.reminder;
    final iosCategory = isFollowUp ? _categoryTaskFollowUp : _categoryTaskStart;

    final hasNextAttempt = attempt < _maxTaskAttempts;
    final nextReminderId = hasNextAttempt
        ? _deriveReminderId(reminderId)
        : null;
    final nextTriggerAt = hasNextAttempt
        ? triggerAt.add(_unansweredReminderDelay)
        : null;
    // Owed, so always allowed — recorded so offered notifications' spacing
    // check knows this moment is taken.
    await _budgetAllows(NotificationKind.taskRetry, at: triggerAt);

    await _zonedSchedule(
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
          category: androidCategory,
          actions: isFollowUp
              ? <AndroidNotificationAction>[
                  AndroidNotificationAction(
                    _actionFollowUpDone,
                    _text(code, 'taskActionDoneLabel'),
                    showsUserInterface: true,
                    cancelNotification: true,
                  ),
                  AndroidNotificationAction(
                    _actionFollowUpLater,
                    _text(code, 'taskActionNotNowLabel'),
                    showsUserInterface: true,
                    cancelNotification: true,
                  ),
                ]
              : null,
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
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    final reminderId = _deriveReminderId(id);
    final watchdogId = 'wdg_$id';
    // Spans the full retry chain (all _maxTaskAttempts, 5 min apart), not
    // just the first interval -- the watchdog should only fire its "truly
    // no response" violation once every attempt has had its turn.
    final dueAt = DateTime.now().add(
      _unansweredReminderDelay * _maxTaskAttempts,
    );
    // Body carries no task detail any more — just the generic command. The
    // real description only ever shows on MandatoryTaskPage, which is the
    // only way left to answer (no notification actions), so there is
    // nothing to leak by tapping the notification body from the lock
    // screen either.
    await _show(
      id,
      _text(code, 'disciplineCommand'),
      _text(code, 'disciplineCommandBody'),
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
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: AndroidNotificationCategory.reminder,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              _actionTaskDone,
              _text(code, 'taskActionDoneLabel'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionTaskNotNow,
              _text(code, 'taskActionNotNowLabel'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionTaskDecline,
              _text(code, 'taskActionDeclineLabel'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionTaskSos,
              _text(code, 'taskActionSosLabel'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
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
        'contextLabel': contextLabel,
        'notificationId': '$id',
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
    // taskAlert is owed, so this always allows — but it still records the
    // send time. Without it, an offered notification's minimumGap check has
    // no idea a task alert just went out, the highest-frequency notification
    // kind in the app.
    await _budgetAllows(NotificationKind.taskAlert, at: fireAt);
    final adjustedDescription = contextLabel == 'eating'
        ? _text(code, 'postMealShieldCommand')
        : AppTexts.localizeCanonicalTextForCode(code, taskDescription);
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    final reminderId = _deriveReminderId(id);
    final watchdogId = 'wdg_$id';
    // Body carries no task detail any more — see showFirstTaskTriggerNotification.
    await _zonedSchedule(
      id,
      _text(code, 'disciplineCommand'),
      _text(code, 'disciplineCommandBody'),
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
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: AndroidNotificationCategory.reminder,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              _actionTaskDone,
              _text(code, 'taskActionDoneLabel'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionTaskNotNow,
              _text(code, 'taskActionNotNowLabel'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionTaskDecline,
              _text(code, 'taskActionDeclineLabel'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionTaskSos,
              _text(code, 'taskActionSosLabel'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
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
        'contextLabel': contextLabel,
        'notificationId': '$id',
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
    //
    // title/body/doneLabel/postponeLabel/declineLabel/sosLabel travel to
    // native purely to keep TaskTriggerSnapshot's cache format stable across
    // a reboot re-arm — TaskTriggerReceiver.onReceive never reads them
    // (the native overlay they used to back is gone; see its class doc).
    await AndroidWatchdogService.scheduleTaskTrigger(
      title: _text(code, 'disciplineCommand'),
      body: adjustedDescription,
      doneLabel: '',
      postponeLabel: '',
      declineLabel: '',
      sosLabel: '',
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

      await _zonedSchedule(
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
      await _zonedSchedule(
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
    for (var i = 0; i < _healthTipLegacySlotCount; i++) {
      await _plugin.cancel(_healthTipBaseId + i);
      await AndroidWatchdogService.cancelHealthTipTrigger(i);
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

    final requestedCount = await StorageService().loadDailyHealthTipCount();
    final dailyCount = requestedCount.clamp(0, _healthTipUserMaxCount).toInt();
    if (dailyCount == 0) {
      return;
    }

    // Distribute the selected number of optional tips across the resolved
    // waking window. General and smoking tips remain available even when no
    // health condition was selected; only disease-specific slots need one.

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
      // Rebuilt at the target wall-clock time rather than sleepAt.add(const
      // Duration(days: 1)): TZDateTime.add() shifts the absolute instant by
      // exactly 24h, which drifts the wall-clock time by the DST offset on
      // a day where one applies. _atDeviceTimeOfDay(addDays: 1) recomputes
      // the correct UTC offset for tomorrow's date instead.
      sleepAt = _atDeviceTimeOfDay(sleepHour, sleepMinute, addDays: 1);
    }

    final windowMinutes = sleepAt.difference(wakeAt).inMinutes;
    final intervalMinutes = windowMinutes ~/ (dailyCount + 1);

    final conditions = (await StorageService().loadHealthConditions())
        .where(_healthTipPrefixByCondition.containsKey)
        .toList(growable: false);
    var conditionCursor = 0;
    var variantCursor = 0;
    final progressReport = await StorageService().buildDailyProgressReport();
    final progress = progressReport.reductionProgress;
    for (var i = 0; i < dailyCount; i++) {
      var fireAt = wakeAt.add(Duration(minutes: intervalMinutes * (i + 1)));
      if (!fireAt.isAfter(now)) {
        // Same DST-safety reasoning as the sleepAt bump above: rebuild at
        // fireAt's own wall-clock hour/minute for tomorrow's date instead
        // of shifting the absolute instant by a raw 24h Duration.
        fireAt = _atDeviceTimeOfDay(fireAt.hour, fireAt.minute, addDays: 1);
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

      final String tipKey;
      if (conditions.isEmpty) {
        // Without a selected condition, all 15 slots use general, smoking-
        // reduction, or condition-neutral wellbeing advice. No disease label
        // is ever shown to a user who did not select one.
        final generalSlot = i % (_healthTipsGeneralCount + _healthTipsSmokingCount + _healthTipsGeneralDiseaseCount);
        if (generalSlot < _healthTipsGeneralCount) {
          tipKey = 'healthTipGeneral${(generalSlot % _healthTipsGeneralCount) + 1}';
        } else if (generalSlot < _healthTipsGeneralCount + _healthTipsSmokingCount) {
          final smokingSlot = generalSlot - _healthTipsGeneralCount;
          tipKey = 'healthTipSmoking${(smokingSlot % _healthTipsSmokingCount) + 1}';
        } else {
          final neutralSlot = generalSlot - _healthTipsGeneralCount - _healthTipsSmokingCount;
          tipKey = 'healthTipGeneralDisease${(neutralSlot % _healthTipsGeneralDiseaseCount) + 1}';
        }
      } else if (i < _healthTipGeneralCount) {
        tipKey = 'healthTipGeneral${(i % _healthTipsGeneralCount) + 1}';
      } else {
        final condition = conditions[conditionCursor % conditions.length];
        final prefix = _healthTipPrefixByCondition[condition]!;
        conditionCursor++;
        tipKey = '$prefix${(variantCursor % _healthTipsPerCondition) + 1}';
        variantCursor++;
      }
      var body =
          '${_text(code, tipKey)}\n${_text(code, 'medicationAdviceDisclaimer')}';
      // Add measured reduction context only when the user has supplied
      // evidence. Silence or an unverified day must never be presented as
      // lung or nicotine recovery.
      if (i % 4 == 0 && progress.verifiedEvidenceDays > 0) {
        final progressLines = <String>[];
        if (progress.loggedToday != null) {
          progressLines.add(
            _text(code, 'reductionLoggedToday')
                .replaceAll('{count}', '${progress.loggedToday}'),
          );
        }
        if (progress.dailyTarget > 0) {
          progressLines.add(
            _text(code, 'reductionTargetToday')
                .replaceAll('{target}', '${progress.dailyTarget}'),
          );
        }
        if (progress.naturalIntervalMinutes > 0 &&
            progress.currentBarrierMinutes > 0) {
          progressLines.add(
            _text(code, 'reductionIntervalDetail')
                .replaceAll('{natural}', '${progress.naturalIntervalMinutes}')
                .replaceAll('{barrier}', '${progress.currentBarrierMinutes}'),
          );
        }
        if (progressLines.isNotEmpty) {
          body = '$body\n\n${progressLines.join('\n')}';
        }
      }

      await _zonedSchedule(
        _healthTipBaseId + i,
        _text(code, 'healthTipTitle'),
        body,
        fireAt,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _healthTipChannelId,
            _text(code, 'channelNameHealthTip'),
            importance: Importance.defaultImportance,
            visibility: NotificationVisibility.private,
            priority: Priority.defaultPriority,
            playSound: true,
            enableVibration: false,
            category: AndroidNotificationCategory.status,
          ),
          iOS: const DarwinNotificationDetails(presentSound: true),
        ),
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode({
          'type': _typeHealthTip,
          'title': _text(code, 'healthTipTitle'),
          'body': body,
          'notificationId': '${_healthTipBaseId + i}',
        }),
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
          // Rebuilt at the same wall-clock hour/minute for tomorrow rather
          // than fireAt.add(const Duration(days: 1)): see the DST note on
          // scheduleHealthConditionAdviceNotifications's equivalent bump.
          fireAt = _atDeviceTimeOfDay(hour, minute, addDays: 1);
        }
        // Medication times are intentional, including when they fall inside
        // the user's sleep window. Do not move them to avoid another kind of
        // notification; the exact dose time must be preserved.

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
        // Owed, so always allowed — recorded so offered notifications'
        // spacing check knows this moment is taken.
        await _budgetAllows(NotificationKind.medication, at: fireAt);

        await _zonedSchedule(
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
              sound: _taskAlarmSound,
              additionalFlags: _insistentFlag,
              audioAttributesUsage: AudioAttributesUsage.alarm,
              category: AndroidNotificationCategory.reminder,
              actions: <AndroidNotificationAction>[
                AndroidNotificationAction(
                  _actionMedicationTaken,
                  _text(code, 'taskActionDoneLabel'),
                  showsUserInterface: true,
                  cancelNotification: true,
                ),
                AndroidNotificationAction(
                  _actionMedicationPostpone,
                  _text(code, 'taskActionNotNowLabel'),
                  showsUserInterface: true,
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
    // Owed, so always allowed — recorded so offered notifications' spacing
    // check knows this moment is taken.
    await _budgetAllows(NotificationKind.taskRetry, at: fireAt);

    await _zonedSchedule(
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
          autoCancel: false,
          onlyAlertOnce: false,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: AndroidNotificationCategory.reminder,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              _actionFollowUpDone,
              _text(code, 'taskActionDoneLabel'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionFollowUpLater,
              _text(code, 'taskActionNotNowLabel'),
              showsUserInterface: true,
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
        'notificationId': '$reminderId',
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
    await _zonedSchedule(
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
    await _show(
      id,
      _text(code, 'taskTimerStartedTitle'),
      '${_text(code, 'taskTimerStartedBody')}\n${AppTexts.localizeCanonicalTextForCode(code, taskTitle)}\n${_text(code, 'taskTimerDuration')}: ${duration.inMinutes} ${_text(code, 'minutesShort')}.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _taskTimerStartedChannelId,
          _text(code, 'channelNameTaskTimerStart'),
          importance: Importance.high,
          visibility: NotificationVisibility.private,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
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
    await _show(
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
    await _show(
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
    await _show(
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
    for (var i = 0; i < _coachCommandMaxSlots; i++) {
      await _plugin.cancel(_coachCommandBaseId + i);
    }
    if (commands.isEmpty) {
      return;
    }

    final scheduleMode = await _resolveAndroidScheduleMode();
    final code = await LanguageService.loadSelectedLanguageCode();
    final now = tz.TZDateTime.now(tz.local);
    final windowStart = _parseWindowStart(predictedRiskWindow);

    final baseHour = windowStart?.hour ?? now.hour;
    final baseMinute = windowStart?.minute ?? now.minute;
    var base = _atDeviceTimeOfDay(baseHour, baseMinute);
    if (!base.isAfter(now)) {
      // Rebuilt at the same wall-clock hour/minute for tomorrow rather than
      // base.add(const Duration(days: 1)) — see the DST note on
      // scheduleHealthConditionAdviceNotifications's equivalent bump.
      base = _atDeviceTimeOfDay(baseHour, baseMinute, addDays: 1);
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
      await _zonedSchedule(
        _coachCommandBaseId + i,
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
                showsUserInterface: true,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                _actionTaskNotNow,
                _text(code, 'taskActionNotNowLabel'),
                showsUserInterface: true,
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

      // `now` is the real moment this scheduling decision happens — the
      // daily budget resets by this, matching this method's own "counted
      // when scheduled" doc above. `when` is the notification's fire
      // time, which for an owed kind (a task alert, a medication
      // reminder) can be hours away and land on the next calendar day;
      // it only feeds the spacing check below, never the day-key
      // bookkeeping. Conflating the two (passing `when` as `now` too) let
      // a late-evening task alert silently reset the whole day's ledger —
      // any offered notification checked afterward today would see the
      // stored date as "tomorrow" and read a fresh, unspent budget. See
      // StorageService.recordNotificationSent's doc comment.
      final now = DateTime.now();
      final when = at ?? now;
      final (sentToday, lastSentAt) = await storage.loadNotificationBudgetState(
        now: now,
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
        now: now,
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

    final code = await LanguageService.loadSelectedLanguageCode();
    final severityKey = switch (severityLevel.toLowerCase()) {
      'severe' => 'severityLevel5',
      'moderate' => 'severityLevel3',
      'mild' => 'severityLevel1',
      _ => 'severityLevel0',
    };
    final body = wheezeDetected
        ? '${_text(code, 'wheezeDetectedResult')}: ${_text(code, severityKey)}'
        : _text(code, 'wheezeNotDetectedResult');

    await navigator.push(
      MaterialPageRoute(builder: (_) => HealthTipPage(body: body)),
    );
  }

  // getNotificationAppLaunchDetails() keeps returning the same launch
  // details on repeat calls within the same Activity/intent (it reads off
  // the Activity's current Intent, which doesn't clear itself) — tracked so
  // a resume-triggered re-check below doesn't replay the same tap.
  static String? _lastHandledColdStartPayload;

  /// Called from main() on cold start, and again on every app resume.
  ///
  /// When the app was fully terminated and a notification tap launched it,
  /// [onDidReceiveNotificationResponse] may never fire because the isolate
  /// wasn't alive at tap time — main()'s call covers that. But a tap can
  /// also relaunch MainActivity as a fresh onCreate while the Dart VM (and
  /// this static state) is still alive from an earlier run, in which case
  /// main() never runs again either — proven via logcat: ActivityTaskManager
  /// starts a new task off the tap's SELECT_NOTIFICATION intent, but no
  /// Flutter-side handler ever fires, not even a failed attempt. Re-running
  /// this same check on every resume catches that case too.
  static Future<void> handleColdStartIfLaunchedFromNotification() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return;
      final response = details?.notificationResponse;
      if (response == null) return;
      if (response.payload != null &&
          response.payload == _lastHandledColdStartPayload) {
        return;
      }
      _lastHandledColdStartPayload = response.payload;
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
