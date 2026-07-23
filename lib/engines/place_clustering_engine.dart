import 'dart:math';

import '../models/significant_place.dart';

/// Matches a single foreground location fix against the already-learned
/// place list. Pure and stateless: it never sees more than one fix at a
/// time and never accumulates a history, by design — the "no raw
/// coordinate storage" requirement is enforced by callers only ever
/// persisting the returned (updated-or-new) [SignificantPlace] centroid,
/// never the fix itself.
class PlaceClusteringEngine {
  static const double defaultRadiusMeters = 150;
  static const double _earthRadiusMeters = 6371000;

  /// Returns the nearest existing place within [radiusMeters], or `null` if
  /// none match.
  SignificantPlace? findNearestPlace({
    required double latitude,
    required double longitude,
    required List<SignificantPlace> existingPlaces,
    double radiusMeters = defaultRadiusMeters,
  }) {
    SignificantPlace? nearest;
    var nearestDistance = double.infinity;

    for (final place in existingPlaces) {
      final distance = distanceMeters(
        lat1: latitude,
        lng1: longitude,
        lat2: place.latitude,
        lng2: place.longitude,
      );
      if (distance <= radiusMeters && distance < nearestDistance) {
        nearest = place;
        nearestDistance = distance;
      }
    }

    return nearest;
  }

  /// Folds one observed fix into the place list: bumps the matching place's
  /// visit count/centroid/lastSeenAt, or — if no match and there's room
  /// under [SignificantPlace.maxPlaces] — appends a new single-visit place.
  /// Returns the updated list; callers persist just this list, never the
  /// fix itself.
  List<SignificantPlace> observeFix({
    required double latitude,
    required double longitude,
    required DateTime observedAt,
    required List<SignificantPlace> existingPlaces,
    double radiusMeters = defaultRadiusMeters,
    String Function()? newPlaceId,
  }) {
    final match = findNearestPlace(
      latitude: latitude,
      longitude: longitude,
      existingPlaces: existingPlaces,
      radiusMeters: radiusMeters,
    );

    if (match != null) {
      // Nudge the centroid toward the new fix (running average) so it
      // converges on the true center as more visits come in, rather than
      // freezing at wherever the first-ever fix happened to land.
      final newVisitCount = match.visitCount + 1;
      final blendedLat =
          ((match.latitude * match.visitCount) + latitude) / newVisitCount;
      final blendedLng =
          ((match.longitude * match.visitCount) + longitude) / newVisitCount;

      final updated = match.copyWith(
        visitCount: newVisitCount,
        latitude: blendedLat,
        longitude: blendedLng,
        lastSeenAt: observedAt,
      );
      return existingPlaces
          .map((place) => place.id == match.id ? updated : place)
          .toList();
    }

    if (existingPlaces.length >= SignificantPlace.maxPlaces) {
      return existingPlaces;
    }

    final newPlace = SignificantPlace(
      id: newPlaceId?.call() ?? 'place_${observedAt.microsecondsSinceEpoch}',
      latitude: latitude,
      longitude: longitude,
      visitCount: 1,
      firstSeenAt: observedAt,
      lastSeenAt: observedAt,
    );
    return [...existingPlaces, newPlace];
  }

  double distanceMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;
}
