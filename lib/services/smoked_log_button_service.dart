import 'dart:io';

import 'package:flutter/services.dart';

import '../models/significant_place.dart';
import 'location_intelligence_service.dart';
import 'storage_service.dart';

/// The always-available "I smoked" button.
///
/// The barrier length and the risky-hour ranking are both computed from when
/// the user actually smokes, so the quality of that record decides how well
/// the whole programme aims. Asking at the end of the day meant asking people
/// to reconstruct their own afternoon from memory; this records the moment as
/// it happens, from wherever they are, without opening the app.
class SmokedLogButtonService {
  static const MethodChannel _channel = MethodChannel('no_smoke/watchdog');

  static const String settingKey = 'smoked_log_button_enabled';

  /// Bump when the disclosure shown before enabling changes materially, same
  /// convention as SleepIntelligenceService.
  static const String consentTextVersion = 'v1';

  final StorageService _storageService;
  final LocationIntelligenceService _locationService;

  /// Every method here is a no-op off Android, since the overlay is an
  /// Android-only surface. Injectable because reading `Platform.isAndroid`
  /// directly made the whole service unreachable from tests, which run on
  /// the host machine — the lifecycle this class exists to manage could not
  /// be checked at all.
  final bool _isAndroid;

  SmokedLogButtonService({
    StorageService? storageService,
    LocationIntelligenceService? locationService,
    bool? isAndroid,
  }) : _storageService = storageService ?? StorageService(),
       _locationService = locationService ?? LocationIntelligenceService(),
       _isAndroid = isAndroid ?? Platform.isAndroid;

  Future<bool> isEnabled() async {
    return (await _storageService.loadSetting(settingKey)) == '1';
  }

  /// Whether the disclosure has been shown and answered before.
  ///
  /// Separate from [isEnabled] so switching the button back on later doesn't
  /// re-explain itself, while a first-ever enable always goes through the
  /// disclosure — the setting alone can't tell those apart, since both start
  /// out unset.
  Future<bool> hasEverConsented() async {
    return (await _storageService.loadSetting(_consentSeenKey)) == '1';
  }

  static const String _consentSeenKey = 'smoked_log_button_consent_seen';

  /// Returns false when the overlay permission hasn't been granted — the
  /// caller is expected to send the user to the permission screen rather than
  /// silently recording the preference for a button that can't appear.
  Future<bool> enable({
    required String notificationTitle,
    required String notificationBody,
    required String actionLabel,
    Map<String, String?> menuLabels = const {},
  }) async {
    if (!_isAndroid) {
      return false;
    }
    final started = await _setNative(
      enabled: true,
      notificationTitle: notificationTitle,
      notificationBody: notificationBody,
      actionLabel: actionLabel,
      menuLabels: menuLabels,
    );
    if (!started) {
      return false;
    }
    await _storageService.saveSetting(settingKey, '1');
    await _storageService.saveSetting(_consentSeenKey, '1');
    await _storageService.recordConsentDecision(
      featureKey: 'smoked_log_button',
      granted: true,
      consentTextVersion: consentTextVersion,
    );
    return true;
  }

  Future<void> disable() async {
    await _storageService.saveSetting(settingKey, '0');
    await _storageService.recordConsentDecision(
      featureKey: 'smoked_log_button',
      granted: false,
      consentTextVersion: consentTextVersion,
    );
    await _setNative(enabled: false);
  }

  /// Re-arms the overlay after a reboot or a process death.
  Future<void> restoreIfEnabled({
    required String notificationTitle,
    required String notificationBody,
    required String actionLabel,
    Map<String, String?> menuLabels = const {},
  }) async {
    if (!_isAndroid || !await isEnabled()) {
      return;
    }
    await _setNative(
      enabled: true,
      notificationTitle: notificationTitle,
      notificationBody: notificationBody,
      actionLabel: actionLabel,
      menuLabels: menuLabels,
    );
  }

  Future<bool> _setNative({
    required bool enabled,
    String? notificationTitle,
    String? notificationBody,
    String? actionLabel,
    Map<String, String?> menuLabels = const {},
  }) async {
    if (!_isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('setSmokedLogButtonEnabled', {
            'enabled': enabled,
            'notificationTitle': notificationTitle,
            'notificationBody': notificationBody,
            'actionLabel': actionLabel,
            ...menuLabels,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// What the app should open on, if the user chose that from the button's
  /// menu while the app wasn't running.
  ///
  /// The menu lives in a native overlay with no Flutter engine behind it, so
  /// it can only leave a note and start the activity — same queue-and-drain
  /// shape as the presses themselves.
  static const String routeSos = 'sos';
  static const String routeSmokedTrigger = 'smoked_trigger';

  Future<String?> drainPendingRoute() async {
    if (!_isAndroid) {
      return null;
    }
    try {
      return await _channel.invokeMethod<String>('consumeSmokedLogRoute');
    } catch (_) {
      return null;
    }
  }

  /// Writes any presses the native button queued into the database.
  ///
  /// The button runs with no Flutter engine alive, so it can only leave the
  /// timestamps behind; this is the only writer that ever touches the table.
  /// Returns the id of each row created — the lock-screen notification
  /// action is a single tap with no hold-to-confirm, so these are what the
  /// caller offers an undo against (see NotificationService's
  /// _syncSmokedLogEventsFromNative).
  Future<List<String>> drainPendingEvents() async {
    if (!_isAndroid) {
      return const [];
    }

    List<dynamic>? raw;
    try {
      raw = await _channel.invokeMethod<List<dynamic>>(
        'consumeSmokedLogEvents',
      );
    } catch (_) {
      return const [];
    }
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final placeId = await _resolvePlaceId();
    final ids = <String>[];
    for (final entry in raw) {
      final map = entry is Map ? entry : null;
      final millis = map?['timestamp'] is num
          ? (map!['timestamp'] as num).toInt()
          : int.tryParse('$entry');
      if (millis == null) continue;
      final id = await _storageService.logSmokingNow(
        timestamp: DateTime.fromMillisecondsSinceEpoch(millis),
        placeId: placeId,
      );
      ids.add(id);
      final trigger = map?['trigger']?.toString() ?? '';
      if (trigger.isNotEmpty) {
        await _storageService.saveFailureTrigger(trigger);
      }
    }
    return ids;
  }

  /// Which of the user's known places they were at, or null.
  ///
  /// Deliberately an id rather than coordinates. The app's whole location
  /// story is that it keeps at most a handful of finalised centroids and
  /// never a trail (see SignificantPlace); attaching raw latitude/longitude to
  /// every cigarette would build exactly the movement history that design
  /// avoids, and answer a question nobody asked. "Which of your usual places"
  /// is all the risky-hour work needs.
  ///
  /// Never allowed to block the record: no permission, no fix, feature off —
  /// the cigarette is still logged, just without a place.
  Future<String?> _resolvePlaceId() async {
    try {
      if (!await _locationService.isEnabled()) {
        return null;
      }
      final position = await _locationService.lastKnownPosition();
      if (position == null) {
        return null;
      }
      final places = await _locationService.loadPlaces();
      return _nearestPlaceId(
        places: places,
        latitude: position.$1,
        longitude: position.$2,
      );
    } catch (_) {
      return null;
    }
  }

  /// Roughly 150 m, in degrees. Close enough to say "the same place" without
  /// needing a real geodesic at this scale.
  static const double _placeMatchDegrees = 0.0015;

  static String? _nearestPlaceId({
    required List<SignificantPlace> places,
    required double latitude,
    required double longitude,
  }) {
    String? bestId;
    var bestDistance = double.infinity;
    for (final place in places) {
      final dLat = place.latitude - latitude;
      final dLon = place.longitude - longitude;
      final distance = (dLat * dLat) + (dLon * dLon);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestId = place.id;
      }
    }
    if (bestId == null ||
        bestDistance > _placeMatchDegrees * _placeMatchDegrees) {
      return null;
    }
    return bestId;
  }
}
