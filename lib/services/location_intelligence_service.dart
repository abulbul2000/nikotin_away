import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../engines/place_clustering_engine.dart';
import '../models/significant_place.dart';
import 'geofencing_service.dart';
import 'storage_service.dart';

/// Orchestrates the opt-in Location Intelligence feature: permission flow
/// (foreground first, then background — the order Android requires),
/// folding a throttled foreground location sample into the learned place
/// list, and keeping the native geofence registration in sync with it.
/// Real ENTER/EXIT detection and the arrival notification are handled
/// entirely natively (GeofenceTransitionReceiver.kt) so they keep working
/// even when the app isn't running — this service only needs to run while
/// the app is open.
class LocationIntelligenceService {
  final StorageService _storageService;
  final PlaceClusteringEngine _clusteringEngine;

  static const Duration _minSampleInterval = Duration(hours: 1);
  static const String consentTextVersion = 'v1';

  LocationIntelligenceService({
    StorageService? storageService,
    PlaceClusteringEngine? clusteringEngine,
  }) : _storageService = storageService ?? StorageService(),
       _clusteringEngine = clusteringEngine ?? PlaceClusteringEngine();

  Future<bool> isEnabled() async {
    return (await _storageService.loadSetting(
          'location_intelligence_enabled',
        )) ==
        '1';
  }

  Future<bool> hasBackgroundPermission() async {
    return await Permission.locationAlways.isGranted;
  }

  /// Requests foreground then background location permission, in the order
  /// Android requires. Returns whether background ended up granted —
  /// foreground-only still lets place-learning run, just without real
  /// geofence registration (Android drops ENTER/EXIT callbacks for a
  /// backgrounded/killed app without ACCESS_BACKGROUND_LOCATION).
  Future<bool> enable() async {
    final foreground = await Permission.locationWhenInUse.request();
    if (!foreground.isGranted) {
      await _storageService.recordConsentDecision(
        featureKey: 'location_intelligence',
        granted: false,
        consentTextVersion: consentTextVersion,
      );
      return false;
    }
    final background = await Permission.locationAlways.request();
    await _storageService.saveSetting('location_intelligence_enabled', '1');
    await _syncGeofences();
    await _storageService.recordConsentDecision(
      featureKey: 'location_intelligence',
      granted: true,
      consentTextVersion: consentTextVersion,
    );
    return background.isGranted;
  }

  Future<void> disable() async {
    await _storageService.saveSetting('location_intelligence_enabled', '0');
    await GeofencingService.clearGeofences();
    await _storageService.recordConsentDecision(
      featureKey: 'location_intelligence',
      granted: false,
      consentTextVersion: consentTextVersion,
    );
  }

  Future<void> updateNotificationText({
    required String title,
    required String body,
  }) async {
    await _storageService.saveSetting('location_notification_title', title);
    await _storageService.saveSetting('location_notification_body', body);
    await _syncGeofences();
  }

  /// The device's last cached fix as (latitude, longitude), or null.
  ///
  /// Deliberately the *cached* one rather than a fresh request: this is
  /// called the instant the user logs a cigarette, and waking the GPS to wait
  /// for a lock would both delay the record and drain the battery for a
  /// question that only needs to resolve to "which of your usual places".
  /// Null whenever there's nothing cached, permission was refused, or the
  /// platform declines — every caller must treat location as optional.
  Future<(double, double)?> lastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) {
        return null;
      }
      return (position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<List<SignificantPlace>> loadPlaces() {
    return _storageService.loadSignificantPlaces();
  }

  /// Call on app foreground/open — throttled internally, so it's cheap to
  /// call unconditionally on every launch.
  Future<void> sampleCurrentLocationIfDue() async {
    if (!await isEnabled()) {
      return;
    }
    if (!await Permission.locationWhenInUse.isGranted) {
      return;
    }

    final lastSampleRaw = await _storageService.loadSetting(
      'location_last_sample_at',
    );
    final lastSample = lastSampleRaw == null
        ? null
        : DateTime.tryParse(lastSampleRaw);
    if (lastSample != null &&
        DateTime.now().difference(lastSample) < _minSampleInterval) {
      return;
    }

    // A GPS/network fix isn't guaranteed to ever arrive (weak signal
    // indoors, flaky Play Services, etc.) — without a time limit this call
    // can hang indefinitely, which was live-reproduced this session as a
    // genuinely stuck UI (see ARCHITECTURE_ROADMAP.md's Phase 6 notes).
    // Caught the same as any other failure: no fix this cycle, try again
    // next time this is due.
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      return;
    }

    await _storageService.saveSetting(
      'location_last_sample_at',
      DateTime.now().toIso8601String(),
    );

    final existingPlaces = await _storageService.loadSignificantPlaces();
    final updatedPlaces = _clusteringEngine.observeFix(
      latitude: position.latitude,
      longitude: position.longitude,
      observedAt: DateTime.now(),
      existingPlaces: existingPlaces,
    );
    await _storageService.saveSignificantPlaces(updatedPlaces);
    await _syncGeofences(places: updatedPlaces);
  }

  Future<void> _syncGeofences({List<SignificantPlace>? places}) async {
    if (!await isEnabled()) {
      return;
    }
    final resolvedPlaces = places ?? await _storageService.loadSignificantPlaces();
    final hasBackground = await hasBackgroundPermission();
    if (!hasBackground || resolvedPlaces.isEmpty) {
      await GeofencingService.clearGeofences();
      return;
    }

    final title =
        await _storageService.loadSetting('location_notification_title') ??
        'Nikotin Away';
    final body =
        await _storageService.loadSetting('location_notification_body') ??
        '';
    await GeofencingService.registerGeofences(
      places: resolvedPlaces,
      notificationTitle: title,
      notificationBody: body,
    );
  }
}
