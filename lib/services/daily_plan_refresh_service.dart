import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'storage_service.dart';
import 'task_assignment_service.dart';

/// Arms/refreshes a once-a-day alarm that builds tomorrow's task plan and
/// schedules its notifications even if the user never opens the app.
///
/// Without this, `TaskAssignmentService.scheduleTodaysTaskNotifications` —
/// and the native `AlarmManager` entries it arms — only ever ran from
/// `home_page.dart`'s `initState`/resume path. Those native alarms do
/// survive the app closing (see `TaskTriggerReceiver.kt`), but nothing
/// created them in the first place on a day the user never opened the app
/// at all: no plan, no alarms, no notifications. This closes that gap with
/// the same native-alarm-plus-headless-Dart-callback pattern the codebase
/// already uses for task triggers, just running once a day instead of once
/// per task.
class DailyPlanRefreshService {
  static const int _alarmId = 7300;

  /// Registers the recurring midnight-ish alarm. Safe to call repeatedly —
  /// `AndroidAlarmManager.periodic` replaces any existing alarm with this
  /// id rather than stacking a second one.
  static Future<void> ensureScheduled() async {
    try {
      await AndroidAlarmManager.initialize();
      await AndroidAlarmManager.periodic(
        const Duration(days: 1),
        _alarmId,
        _refreshCallback,
        startAt: _nextRefreshTime(),
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    } catch (_) {
      // Best-effort: a user still opening the app daily is unaffected
      // either way, and this must never block app startup.
    }
  }

  /// A few minutes past midnight, not exactly on it — avoids this alarm and
  /// every other app's midnight-aligned alarms firing in the same instant,
  /// and gives any date-rollover-dependent storage reads (loadSleepTime,
  /// etc.) a moment of slack past the actual day boundary.
  static DateTime _nextRefreshTime() {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, 0, 5);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }
}

/// Runs in a separate background isolate with no Flutter engine/UI/
/// BuildContext — only plugins with their own Android-side background
/// execution support (sqflite, flutter_local_notifications, shared_preferences)
/// work here. Must stay a top-level or static function: AndroidAlarmManager
/// looks it up by reflection through this exact `vm:entry-point` pragma.
@pragma('vm:entry-point')
void _refreshCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    tz.initializeTimeZones();
    await FlutterLocalNotificationsPlugin().initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await TaskAssignmentService(StorageService())
        .scheduleTodaysTaskNotifications(allowBeforeWakeForBackground: true);
  } catch (error, stackTrace) {
    // Keep the callback alive, but leave a diagnostic trail for the next
    // foreground refresh instead of making a failed background run invisible.
    debugPrint('[DailyPlanRefresh] background refresh failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
