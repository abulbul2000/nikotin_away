import 'dart:io';

import 'package:flutter/services.dart';

/// Android-native foreground servis + alarm tabanlı watchdog köprüsü.
///
/// iOS / masaüstü gibi Android-dışı platformlarda tüm metodlar sessizce
/// no-op döner; uygulama çökmez ancak yanıtsızlık ihlalleri üretilmez.
/// iOS için watchdog desteği gerekiyorsa bu sınıfa paralel bir
/// iOS implementasyonu eklenmelidir.
class AndroidWatchdogService {
  static const MethodChannel _channel = MethodChannel('no_smoke/watchdog');

  static bool get _isAndroid => Platform.isAndroid;

  static Future<void> startWatchdog({
    required String taskTitle,
    required String watchdogId,
    required DateTime dueAt,
    required String foregroundBody,
    required String violationTitle,
    required String violationBody,
    required String foregroundChannelName,
    required String violationChannelName,
  }) async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod('startWatchdog', {
        'taskTitle': taskTitle,
        'watchdogId': watchdogId,
        'dueAtMillis': dueAt.millisecondsSinceEpoch,
        'foregroundBody': foregroundBody,
        'violationTitle': violationTitle,
        'violationBody': violationBody,
        'foregroundChannelName': foregroundChannelName,
        'violationChannelName': violationChannelName,
      });
    } catch (_) {
      // Best-effort: a platform exception here (e.g. the OS refusing a
      // foreground-service start) must not take down whichever caller
      // triggered this — the task-trigger notification this normally backs
      // up has typically already been shown by the time this runs, so the
      // user just loses the unanswered-task follow-up/violation tracking
      // for this one task rather than the notification itself.
    }
  }

  /// The mandatory-task overlay's foreground-service notification is a
  /// fixed, locale-only string (not tied to any one task), so it's pushed
  /// once here rather than on every showOverlay/showInfoOverlay call.
  static Future<void> setTaskOverlayChannelInfo({
    required String channelName,
    required String channelDescription,
    required String foregroundBody,
  }) async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod('setTaskOverlayChannelInfo', {
        'channelName': channelName,
        'channelDescription': channelDescription,
        'foregroundBody': foregroundBody,
      });
    } catch (_) {
      // Best-effort: falls back to the service's own English defaults.
    }
  }

  static Future<void> acknowledgeWatchdog(String watchdogId) async {
    if (!_isAndroid || watchdogId.trim().isEmpty) {
      return;
    }
    await _channel.invokeMethod('ackWatchdog', {'watchdogId': watchdogId});
  }

  /// For callers that only know the task's title, not its watchdogId —
  /// HomePage's own mandatory-gate path (opened from its resume/foreground
  /// check, not from a notification tap) is the one caller in that
  /// position. Native looks the id up by scanning active watchdogs.
  static Future<void> acknowledgeWatchdogByTaskTitle(String taskTitle) async {
    if (!_isAndroid || taskTitle.trim().isEmpty) {
      return;
    }
    await _channel.invokeMethod('ackWatchdogByTaskTitle', {
      'taskTitle': taskTitle,
    });
  }

  /// Cancels every currently-active watchdog's native alarm and discards
  /// any already-queued violations, without ever draining them to Dart.
  /// Called from Settings' Reset Data / Delete Account flows so a watchdog
  /// armed before the reset can't fire afterward and write a violation row
  /// referencing a task from before the reset into the just-cleared
  /// database (see WatchdogStore.cancelAllActiveAndDiscardViolations's doc
  /// comment on the native side).
  static Future<void> cancelAllWatchdogs() async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod('cancelAllWatchdogs');
    } catch (_) {
      // Best-effort: a failure here must not block the rest of the reset.
    }
  }

  /// Opens the native task overlay for a notification body tap. This works
  /// while another app is visible and avoids routing to whichever Flutter
  /// page happened to be open.
  /// Opens a read-only full-screen overlay for non-task notification taps.
  static Future<void> showInfoOverlayFromNotification({
    required String title,
    required String body,
    required String dismissLabel,
  }) async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod('showInfoOverlayFromNotification', {
        'title': title,
        'body': body,
        'dismissLabel': dismissLabel,
      });
    } catch (_) {
      // The regular notification remains available if the overlay is not
      // available on this device.
    }
  }

  /// Opens the native "did you smoke?" overlay for a task-confirm
  /// notification body tap, with real Evet/Hayır buttons — the same answer
  /// its action buttons offer, rather than a dismiss-only acknowledgment
  /// that leaves the question unanswered.
  static Future<void> showConfirmOverlayFromNotification({
    required String title,
    required String body,
    required String yesLabel,
    required String noLabel,
    required String taskTitle,
  }) async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod('showConfirmOverlayFromNotification', {
        'title': title,
        'body': body,
        'yesLabel': yesLabel,
        'noLabel': noLabel,
        'taskTitle': taskTitle,
      });
    } catch (_) {
      // The regular notification remains available if the overlay is not
      // available on this device.
    }
  }

  static Future<List<Map<String, dynamic>>> consumeViolations() async {
    if (!_isAndroid) {
      return const [];
    }

    final raw = await _channel.invokeMethod<List<dynamic>>(
      'consumeWatchdogViolations',
    );
    if (raw == null) {
      return const [];
    }

    return raw
        .whereType<Map>()
        .map(
          (entry) => entry.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();
  }

  /// Arms a native alarm for the moment [triggerAt] arrives, which then shows
  /// the task overlay and starts that task's watchdog.
  ///
  /// A scheduled notification can't do either of those itself: both need code
  /// running at fire time, and with the app closed there is no Dart alive
  /// then. Starting the watchdog from here (rather than at schedule time)
  /// also keeps its timeout window tied to when the user was actually asked,
  /// and stops two tasks scheduled hours apart from overwriting each other's
  /// watchdog state.
  static Future<void> scheduleTaskTrigger({
    required String title,
    required String body,
    required String doneLabel,

    /// Blank hides the button — postpone and SOS are each capped at two uses
    /// per task, and a button whose answer is "no, not any more" is worse
    /// than no button.
    required String postponeLabel,
    required String declineLabel,
    required String sosLabel,
    required String watchdogId,
    required String taskTitle,
    required DateTime triggerAt,
    required Duration watchdogWindow,

    /// Carried through to the native alarm's Intent extras so that when it
    /// fires with the app dead, TaskTriggerReceiver can start
    /// NoResponseWatchdogService with the same localized strings
    /// [startWatchdog] would have used had the app been alive to call it
    /// directly.
    required String watchdogForegroundBody,
    required String watchdogViolationTitle,
    required String watchdogViolationBody,
    required String watchdogForegroundChannelName,
    required String watchdogViolationChannelName,
  }) async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod('scheduleTaskTrigger', {
        'title': title,
        'body': body,
        'doneLabel': doneLabel,
        'postponeLabel': postponeLabel,
        'declineLabel': declineLabel,
        'sosLabel': sosLabel,
        'watchdogId': watchdogId,
        'taskTitle': taskTitle,
        'triggerAtMillis': triggerAt.millisecondsSinceEpoch,
        'watchdogWindowMillis': watchdogWindow.inMilliseconds,
        'watchdogForegroundBody': watchdogForegroundBody,
        'watchdogViolationTitle': watchdogViolationTitle,
        'watchdogViolationBody': watchdogViolationBody,
        'watchdogForegroundChannelName': watchdogForegroundChannelName,
        'watchdogViolationChannelName': watchdogViolationChannelName,
      });
    } catch (_) {
      // Best-effort: the scheduled notification is still the user-facing
      // prompt, so a failed alarm degrades rather than losing the task.
    }
  }

  static Future<void> cancelTaskTrigger(String watchdogId) async {
    if (!_isAndroid || watchdogId.trim().isEmpty) {
      return;
    }
    try {
      await _channel.invokeMethod('cancelTaskTrigger', {
        'watchdogId': watchdogId,
      });
    } catch (_) {
      // Best-effort.
    }
  }

  /// Deferrals the delivery gate recorded while the app wasn't running.
  ///
  /// Each entry has `watchdogId`, `reason`, and `createdAtMillis`. The gate
  /// runs in a broadcast receiver with no Flutter engine behind it, so this
  /// is the only way those events reach the database.
  static Future<List<Map<String, dynamic>>> consumeDeliveryDeferrals() async {
    if (!_isAndroid) {
      return const [];
    }
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'consumeDeliveryDeferrals',
      );
      if (raw == null) {
        return const [];
      }
      return raw
          .whereType<Map>()
          .map(
            (entry) =>
                entry.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Arms a native alarm that shows a health tip as an info overlay at
  /// [triggerAt], on top of whatever app is in the foreground — mirrors
  /// [scheduleTaskTrigger] but for read-only content with no watchdog or
  /// outcome to report back.
  static Future<void> scheduleHealthTipTrigger({
    required int slot,
    required String title,
    required String body,
    required String dismissLabel,
    required DateTime triggerAt,
  }) async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod('scheduleHealthTipTrigger', {
        'slot': slot,
        'title': title,
        'body': body,
        'dismissLabel': dismissLabel,
        'triggerAtMillis': triggerAt.millisecondsSinceEpoch,
      });
    } catch (_) {
      // Best-effort: the scheduled notification is still the user-facing
      // prompt, so a failed alarm degrades rather than losing the tip.
    }
  }

  static Future<void> cancelHealthTipTrigger(int slot) async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod('cancelHealthTipTrigger', {'slot': slot});
    } catch (_) {
      // Best-effort.
    }
  }

  /// Arms a native alarm that shows a reminder (breath test, weekly survey)
  /// as an Open/Postpone overlay at [triggerAt]. "Open" launches the app and
  /// leaves [route] for [consumeReminderOverlayRoute] to pick up on resume;
  /// "Postpone" re-arms itself an hour out entirely on the native side, so it
  /// still works even if Dart never runs again before the hour is up.
  static Future<void> scheduleReminderOverlayTrigger({
    required int slot,
    required String reminderId,
    required String title,
    required String body,
    required String route,
    required String openLabel,
    required String postponeLabel,
    required DateTime triggerAt,
  }) async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod('scheduleReminderOverlayTrigger', {
        'slot': slot,
        'reminderId': reminderId,
        'title': title,
        'body': body,
        'route': route,
        'openLabel': openLabel,
        'postponeLabel': postponeLabel,
        'triggerAtMillis': triggerAt.millisecondsSinceEpoch,
      });
    } catch (_) {
      // Best-effort: the scheduled notification is still the user-facing
      // prompt, so a failed alarm degrades rather than losing the reminder.
    }
  }

  /// The route (if any) a reminder overlay's "Open" button queued while the
  /// app wasn't running to navigate directly.
  static Future<String?> consumeReminderOverlayRoute() async {
    if (!_isAndroid) {
      return null;
    }
    try {
      return await _channel.invokeMethod<String>('consumeReminderOverlayRoute');
    } catch (_) {
      return null;
    }
  }

  /// The action (if any) queued by a tap on one of the launcher icon's
  /// long-press shortcuts (see shortcuts.xml / MainActivity.ShortcutStore).
  /// One of 'smoked_now', 'craving', 'self_challenge', or null when no
  /// shortcut was tapped since the last drain.
  static Future<String?> consumePendingShortcutAction() async {
    if (!_isAndroid) {
      return null;
    }
    try {
      return await _channel.invokeMethod<String>(
        'consumePendingShortcutAction',
      );
    } catch (_) {
      return null;
    }
  }

  /// Watchdog ids the native delivery-gate queue closed out as `expired`
  /// while the app was closed — two or more tasks fell due during the same
  /// DND/gaming stretch, and everything past the two-task limit is dropped
  /// here rather than delivered in a stack once the block clears.
  static Future<List<Map<String, dynamic>>>
  consumePendingDeliveryExpirations() async {
    if (!_isAndroid) {
      return const [];
    }
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'consumePendingDeliveryExpirations',
      );
      if (raw == null) {
        return const [];
      }
      return raw
          .whereType<Map>()
          .map(
            (entry) =>
                entry.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Map<String, dynamic>>> consumeTaskOverlayOutcomes() async {
    if (!_isAndroid) {
      return const [];
    }
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'consumeTaskOverlayOutcomes',
      );
      if (raw == null) {
        return const [];
      }
      return raw
          .whereType<Map>()
          .map(
            (entry) =>
                entry.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
