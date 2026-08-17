import 'package:flutter/services.dart';

import '../models/significant_place.dart';

/// Thin wrapper around the native `no_smoke/geofencing` channel — actual
/// geofence registration and transition handling both live natively
/// (MainActivity.kt / GeofenceTransitionReceiver.kt) via Play Services'
/// GeofencingClient, since that's the only way transitions fire reliably
/// while the app isn't running.
class GeofencingService {
  static const MethodChannel _channel = MethodChannel('no_smoke/geofencing');

  // A stuck native call (or a Play Services round-trip that never invokes
  // its callback) would otherwise hang the caller forever — a real,
  // live-reproduced symptom this session (see location_intelligence_page's
  // _load, and ARCHITECTURE_ROADMAP.md's Phase 6 notes on this device's
  // Play Services rejecting geofence registration).
  static const _callTimeout = Duration(seconds: 10);

  static Future<void> registerGeofences({
    required List<SignificantPlace> places,
    required String notificationTitle,
    required String notificationBody,
    required String channelName,
    required String channelDescription,
    List<String> riskPlaceIds = const <String>[],
  }) async {
    try {
      await _channel
          .invokeMethod('registerGeofences', {
            'places': places
                .map(
                  (place) => {
                    'id': place.id,
                    'latitude': place.latitude,
                    'longitude': place.longitude,
                  },
                )
                .toList(),
            'notificationTitle': notificationTitle,
            'notificationBody': notificationBody,
            'channelName': channelName,
            'channelDescription': channelDescription,
            'riskPlaceIds': riskPlaceIds,
          })
          .timeout(_callTimeout);
    } catch (_) {
      // Best-effort — platforms without this channel (e.g. iOS, tests), a
      // native-side rejection, or a timeout are all treated the same.
    }
  }

  static Future<void> clearGeofences() async {
    try {
      await _channel.invokeMethod('clearGeofences').timeout(_callTimeout);
    } catch (_) {
      // Best-effort.
    }
  }
}
