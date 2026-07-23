import 'package:flutter/services.dart';

import '../models/wearable_health_snapshot.dart';
import '../engines/wearable_signal_engine.dart';

/// Read-only Health Connect access (Phase 9 wearable spike), talking
/// directly to a native `MethodChannel` (see MainActivity.kt) rather than a
/// third-party Flutter wrapper — the only one on pub.dev was too
/// unmaintained for this project's Android Gradle Plugin version (see
/// ARCHITECTURE_ROADMAP.md's Phase 9 notes for what was tried).
///
/// This app never talks to a wearable directly — Wear OS/Galaxy
/// Watch/Fitbit/Garmin companion apps write into Health Connect on their
/// own, and this service only reads whatever is already there. Every
/// method is defensive: Health Connect being absent, unauthorized, or a
/// platform-channel failure all degrade to "no data" rather than throwing —
/// this is an optional, best-effort signal, never a dependency the rest of
/// the app can break on.
class HealthConnectService {
  static const MethodChannel _channel = MethodChannel('no_smoke/health_connect');

  final WearableSignalEngine _signalEngine;

  HealthConnectService({WearableSignalEngine? signalEngine})
    : _signalEngine = signalEngine ?? WearableSignalEngine();

  Future<bool> isAvailable() async {
    try {
      return (await _channel.invokeMethod<bool>('isAvailable')) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> promptInstall() async {
    try {
      await _channel.invokeMethod('installHealthConnect');
    } catch (_) {
      // Best-effort — if the Play Store intent can't be started, there's
      // nothing more this app can do about it.
    }
  }

  Future<bool> hasPermissions() async {
    try {
      return (await _channel.invokeMethod<bool>('hasPermissions')) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    try {
      return (await _channel.invokeMethod<bool>('requestPermissions')) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Reads the last [heartRateWindow] of heart-rate samples and the most
  /// recent sleep session within [sleepWindow], and folds them into a
  /// snapshot. Returns [WearableHealthSnapshot.empty] on any failure.
  Future<WearableHealthSnapshot> fetchRecentSnapshot({
    Duration heartRateWindow = const Duration(hours: 6),
    Duration sleepWindow = const Duration(hours: 30),
  }) async {
    final now = DateTime.now();
    double? latestBpm;
    DateTime? latestAt;
    double? baselineBpm;
    Duration? sleepDuration;
    DateTime? sleepEnd;

    try {
      final raw = await _channel.invokeMethod<List<Object?>>(
        'getHeartRateRecords',
        {
          'startTimeMillis': now
              .subtract(heartRateWindow)
              .millisecondsSinceEpoch,
          'endTimeMillis': now.millisecondsSinceEpoch,
        },
      );
      final samples = _extractHeartRateSamples(raw);
      if (samples.isNotEmpty) {
        samples.sort((a, b) => b.$1.compareTo(a.$1));
        latestAt = samples.first.$1;
        latestBpm = samples.first.$2;
        baselineBpm = _signalEngine.computeBaselineBpm(
          samples.map((s) => s.$2).toList(),
        );
      }
    } catch (_) {
      // No usable heart-rate data — leave the fields null.
    }

    try {
      final raw = await _channel.invokeMethod<List<Object?>>(
        'getSleepSessions',
        {
          'startTimeMillis': now.subtract(sleepWindow).millisecondsSinceEpoch,
          'endTimeMillis': now.millisecondsSinceEpoch,
        },
      );
      final session = _extractLatestSleepSession(raw);
      if (session != null) {
        sleepEnd = session.$2;
        sleepDuration = session.$2.difference(session.$1);
      }
    } catch (_) {
      // No usable sleep session — leave the fields null.
    }

    return WearableHealthSnapshot(
      latestHeartRateBpm: latestBpm,
      latestHeartRateAt: latestAt,
      baselineHeartRateBpm: baselineBpm,
      lastSleepSessionDuration: sleepDuration,
      lastSleepSessionEnd: sleepEnd,
    );
  }

  List<(DateTime, double)> _extractHeartRateSamples(List<Object?>? raw) {
    final results = <(DateTime, double)>[];
    if (raw == null) {
      return results;
    }
    for (final entry in raw) {
      if (entry is! Map) {
        continue;
      }
      final bpm = _asDouble(entry['bpm']);
      final time = _asDateTime(entry['timeMillis']);
      if (bpm != null && bpm > 0 && time != null) {
        results.add((time, bpm));
      }
    }
    return results;
  }

  (DateTime, DateTime)? _extractLatestSleepSession(List<Object?>? raw) {
    if (raw == null) {
      return null;
    }
    (DateTime, DateTime)? latest;
    for (final entry in raw) {
      if (entry is! Map) {
        continue;
      }
      final start = _asDateTime(entry['startTimeMillis']);
      final end = _asDateTime(entry['endTimeMillis']);
      if (start == null || end == null || !end.isAfter(start)) {
        continue;
      }
      if (latest == null || end.isAfter(latest.$2)) {
        latest = (start, end);
      }
    }
    return latest;
  }

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt(),
        isUtc: true,
      ).toLocal();
    }
    return null;
  }
}
