import 'package:flutter/services.dart';

import '../models/significant_place.dart';

/// Thin wrapper around the native `no_smoke/geofencing` channel — actual
/// geofence registration and transition handling both live natively
/// (MainActivity.kt / GeofenceTransitionReceiver.kt) via Play Services'
/// GeofencingClient, since that's the only way transitions fire reliably
/// while the app isn't running.
class GeofencingService {
  static const MethodChannel _channel = MethodChannel('no_smoke/geofencing');

  static Future<void> registerGeofences({
    required List<SignificantPlace> places,
    required String notificationTitle,
    required String notificationBody,
  }) async {
    try {
      await _channel.invokeMethod('registerGeofences', {
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
      });
    } catch (_) {
      // Best-effort on platforms without this channel (e.g. iOS, tests).
    }
  }

  static Future<void> clearGeofences() async {
    try {
      await _channel.invokeMethod('clearGeofences');
    } catch (_) {
      // Best-effort.
    }
  }
}
