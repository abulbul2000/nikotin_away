import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/app_texts.dart';
import '../pages/breath_test_page.dart';
import 'android_watchdog_service.dart';
import 'language_service.dart';
import 'phone_state_service.dart';
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
  static const String _typeWeeklySurvey = 'weekly_survey';

  static const String _actionTaskDone = 'task_done';
  static const String _actionTaskNotNow = 'task_not_now';
  static const String _actionFollowUpDone = 'followup_done';
  static const String _actionFollowUpLater = 'followup_later';
  static const String _actionSmokedNo = 'smoked_no';

  static const String _categoryTaskStart = 'task_start_category';
  static const String _categoryTaskFollowUp = 'task_followup_category';
  static const String _taskStartChannelId = 'task_start_channel_v4';
  static const String _taskFollowUpChannelId = 'task_followup_channel_v5';
  static const String _taskEscalationChannelId = 'task_escalation_channel_v1';
  static const String _breathReminderChannelId = 'breath_reminder_channel_v3';
  static const String _weeklySurveyChannelId = 'weekly_survey_channel_v1';
  static const int _weeklySurveyNotificationId = 700001;
  static const int _dailyBreathReminderBaseId = 420100;
  static const int _dailyBreathReminderMaxSlots = 6;
  static const int _notificationTimeoutMs = 15000;
  static const Duration _unansweredReminderDelay = Duration(minutes: 10);
  static final Int32List _insistentFlag = Int32List.fromList(<int>[4]);
  static final Int64List _taskVibrationPattern = Int64List.fromList(<int>[
    0,
    15000,
  ]);

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
  }

  static Future<void> refreshLocalizedResources() async {
    await initialize(navigatorKey: _navigatorKey);
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
          details: '10 minutes passed with no response to task notification.',
          createdAt: createdAt,
        );
      }
    } catch (_) {
      // Keep notification flow resilient even if native watchdog sync fails.
    }
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
    _processNotificationResponse(response, allowNavigation: true);
  }

  static void handleBackgroundNotificationResponse(
    NotificationResponse response,
  ) {
    _processNotificationResponse(response, allowNavigation: false);
  }

  static void _processNotificationResponse(
    NotificationResponse response, {
    required bool allowNavigation,
  }) {
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
      final context = _navigatorKey?.currentContext;
      if (context != null) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const BreathTestPage()));
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
        'actionId': actionId ?? '',
      };

      if (_taskActionController.hasListener) {
        _taskActionController.add(event);
      } else {
        unawaited(_handleActionWithoutUi(event));
      }
    }
  }

  static Future<void> _handleActionWithoutUi(Map<String, String> event) async {
    final taskTitle = event['taskTitle']?.trim() ?? '';
    final actionId = event['actionId']?.trim() ?? '';
    if (taskTitle.isEmpty || actionId.isEmpty) {
      return;
    }

    if (actionId == _actionTaskDone) {
      final delay = _resolveInitialTaskDelay(taskTitle);
      await showTaskTimerStartedNotification(
        taskTitle: taskTitle,
        duration: delay,
      );
      await scheduleTaskFollowUpReminder(taskTitle: taskTitle, delay: delay);
      return;
    }

    if (actionId == _actionTaskNotNow) {
      await scheduleFirstTaskTriggerNotification(
        taskDescription: taskTitle,
        delay: const Duration(minutes: 10),
      );
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

  static Future<void> _scheduleUnansweredTaskUpdateReminder({
    required String taskTitle,
    required String type,
    required int reminderId,
    required tz.TZDateTime triggerAt,
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
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          additionalFlags: _insistentFlag,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          timeoutAfter: _notificationTimeoutMs,
          category: androidCategory,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              isFollowUp ? _actionFollowUpDone : _actionTaskDone,
              _text(code, 'taskActionDoneLabel'),
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              isFollowUp ? _actionFollowUpLater : _actionTaskNotNow,
              _text(code, 'taskActionNotNowLabel'),
              showsUserInterface: true,
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
      payload: jsonEncode({'type': type, 'taskTitle': taskTitle}),
    );
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
    final adjustedDescription = contextLabel == 'eating'
        ? _text(code, 'postMealShieldCommand')
      : AppTexts.localizeCanonicalTextForCode(code, taskDescription);
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    final reminderId = _deriveReminderId(id);
    final watchdogId = 'wdg_$id';
    final dueAt = DateTime.now().add(_unansweredReminderDelay);
    await _plugin.show(
      id,
      _text(code, 'disciplineCommand'),
      '${_text(code, 'disciplineCommandBody')}\n$adjustedDescription',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _taskStartChannelId,
          'İlk görev tetikleme',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          additionalFlags: _insistentFlag,
          autoCancel: false,
          ongoing: true,
          onlyAlertOnce: false,
          timeoutAfter: _notificationTimeoutMs,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
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
        ),
      ),
      payload: jsonEncode({
        'type': _typeTaskStart,
        'taskTitle': taskTitle,
        'reminderId': '$reminderId',
        'watchdogId': watchdogId,
      }),
    );

    await AndroidWatchdogService.startWatchdog(
      taskTitle: taskTitle,
      watchdogId: watchdogId,
      dueAt: dueAt,
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
    final adjustedDescription = contextLabel == 'eating'
        ? _text(code, 'postMealShieldCommand')
      : AppTexts.localizeCanonicalTextForCode(code, taskDescription);
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    final reminderId = _deriveReminderId(id);
    final watchdogId = 'wdg_$id';
    final dueAt = fireAt.add(_unansweredReminderDelay);
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
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
          additionalFlags: _insistentFlag,
          autoCancel: false,
          ongoing: true,
          onlyAlertOnce: false,
          timeoutAfter: _notificationTimeoutMs,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
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
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': _typeTaskStart,
        'taskTitle': adjustedDescription,
        'reminderId': '$reminderId',
        'watchdogId': watchdogId,
      }),
    );

    await AndroidWatchdogService.startWatchdog(
      taskTitle: adjustedDescription,
      watchdogId: watchdogId,
      dueAt: dueAt,
    );

    await _scheduleUnansweredTaskUpdateReminder(
      taskTitle: adjustedDescription,
      type: _typeTaskStart,
      reminderId: reminderId,
      triggerAt: fireAt.add(_unansweredReminderDelay),
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

    var wakeAt = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      wakeHour,
      wakeMinute,
    );
    var sleepAt = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      sleepHour,
      sleepMinute,
    );
    if (!sleepAt.isAfter(wakeAt)) {
      sleepAt = sleepAt.add(const Duration(days: 1));
    }

    final windowMinutes = sleepAt.difference(wakeAt).inMinutes;
    final count = safePreferred;
    final intervalMinutes = count <= 1
        ? (windowMinutes ~/ 2)
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
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _breathReminderChannelId,
            'Nefes testi hatırlatıcı',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: DarwinNotificationDetails(presentSound: true),
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
      final fallbackAt = now.add(Duration(minutes: 60 + (i * 45)));
      await _plugin.zonedSchedule(
        _dailyBreathReminderBaseId + i,
        _text(code, 'breathReminderTitle'),
        _text(code, 'breathReminderBody'),
        fallbackAt,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _breathReminderChannelId,
            'Nefes testi hatırlatıcı',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: DarwinNotificationDetails(presentSound: true),
        ),
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode({'type': _typeBreath}),
      );
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
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _taskVibrationPattern,
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
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _weeklySurveyChannelId,
          'Haftalik anket hatirlatici',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
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
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _taskStartChannelId,
          'Task timer start',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      ),
    );
  }

  static Future<void> showDurationBarrierStartedNotification({
    required String taskTitle,
    required Duration duration,
  }) async {
    final code = await LanguageService.loadSelectedLanguageCode();
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    final durationText = _formatBarrierDuration(duration, code);
    final instruction = code == 'tr'
        ? 'Lütfen önümüzdeki $durationText boyunca sigara içmeyin.'
        : 'Please do not smoke for the next $durationText.';
    await _plugin.show(
      id,
      _text(code, 'barrierStartedTitle'),
      '$instruction\n${AppTexts.localizeCanonicalTextForCode(code, taskTitle)}\n${_text(code, 'barrierStartedDuration')}: $durationText.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _taskStartChannelId,
          'Duration barrier call',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      ),
    );
  }

  static String _formatBarrierDuration(Duration duration, String code) {
    final totalMinutes = duration.inMinutes;
    if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      final remainingMinutes = totalMinutes % 60;
      if (remainingMinutes == 0) {
        return code == 'tr' ? '$hours saat' : '$hours hour${hours == 1 ? '' : 's'}';
      }
      return code == 'tr'
          ? '$hours saat $remainingMinutes dakika'
          : '$hours hour${hours == 1 ? '' : 's'} $remainingMinutes minute${remainingMinutes == 1 ? '' : 's'}';
    }
    return code == 'tr'
        ? '$totalMinutes dakika'
        : '$totalMinutes minute${totalMinutes == 1 ? '' : 's'}';
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

    var base = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
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
      final fireAt = normalizedFirstAt
          .add(Duration(minutes: i * safeSpacing))
          .add(Duration(minutes: extraDelay));
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
            priority: Priority.high,
            playSound: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            category: AndroidNotificationCategory.call,
            fullScreenIntent: true,
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
        payload: jsonEncode({
          'type': _typeTaskStart,
          'taskTitle': commands[i],
        }),
      );
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
