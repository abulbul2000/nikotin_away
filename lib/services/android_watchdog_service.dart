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
  }) async {
    if (!_isAndroid) {
      return;
    }
    await _channel.invokeMethod('startWatchdog', {
      'taskTitle': taskTitle,
      'watchdogId': watchdogId,
      'dueAtMillis': dueAt.millisecondsSinceEpoch,
    });
  }

  static Future<void> acknowledgeWatchdog(String watchdogId) async {
    if (!_isAndroid || watchdogId.trim().isEmpty) {
      return;
    }
    await _channel.invokeMethod('ackWatchdog', {'watchdogId': watchdogId});
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
        .map((entry) => entry.map(
              (key, value) => MapEntry(key.toString(), value),
            ))
        .toList();
  }

  /// Draws the task prompt as a system overlay over whatever app is in the
  /// foreground (requires "display over other apps"; no-ops to `false` if
  /// that permission hasn't been granted). Complements, doesn't replace, the
  /// task notification -- callers should fire both.
  static Future<bool> showTaskOverlay({
    required String title,
    required String body,
    required String doneLabel,
    required String declineLabel,
    required String watchdogId,
    required String taskTitle,
  }) async {
    if (!_isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('showTaskOverlay', {
            'title': title,
            'body': body,
            'doneLabel': doneLabel,
            'declineLabel': declineLabel,
            'watchdogId': watchdogId,
            'taskTitle': taskTitle,
          }) ??
          false;
    } catch (_) {
      return false;
    }
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
    required String declineLabel,
    required String watchdogId,
    required String taskTitle,
    required DateTime triggerAt,
    required Duration watchdogWindow,
  }) async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod('scheduleTaskTrigger', {
        'title': title,
        'body': body,
        'doneLabel': doneLabel,
        'declineLabel': declineLabel,
        'watchdogId': watchdogId,
        'taskTitle': taskTitle,
        'triggerAtMillis': triggerAt.millisecondsSinceEpoch,
        'watchdogWindowMillis': watchdogWindow.inMilliseconds,
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

  static Future<void> dismissTaskOverlay() async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod('dismissTaskOverlay');
    } catch (_) {
      // Best-effort.
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
          .map((entry) => entry.map(
                (key, value) => MapEntry(key.toString(), value),
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
