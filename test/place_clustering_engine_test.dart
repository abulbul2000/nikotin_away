import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/place_clustering_engine.dart';
import 'package:no_smoke/models/significant_place.dart';

void main() {
  group('PlaceClusteringEngine', () {
    final engine = PlaceClusteringEngine();

    test('distanceMeters is ~0 for identical coordinates and grows with '
        'separation', () {
      final same = engine.distanceMeters(
        lat1: 41.0082,
        lng1: 28.9784,
        lat2: 41.0082,
        lng2: 28.9784,
      );
      expect(same, closeTo(0, 1));

      // Roughly 1 degree of latitude ~= 111km.
      final farther = engine.distanceMeters(
        lat1: 41.0082,
        lng1: 28.9784,
        lat2: 42.0082,
        lng2: 28.9784,
      );
      expect(farther, greaterThan(100000));
    });

    test('observeFix creates a new place when none are within radius', () {
      final result = engine.observeFix(
        latitude: 41.0082,
        longitude: 28.9784,
        observedAt: DateTime(2026, 1, 1),
        existingPlaces: const [],
      );

      expect(result, hasLength(1));
      expect(result.first.visitCount, 1);
      expect(result.first.latitude, 41.0082);
    });

    test('observeFix increments visit count and blends centroid for a '
        'nearby fix instead of creating a duplicate place', () {
      final firstPass = engine.observeFix(
        latitude: 41.0082,
        longitude: 28.9784,
        observedAt: DateTime(2026, 1, 1),
        existingPlaces: const [],
      );

      // ~15m north — well within the 150m default radius.
      final secondPass = engine.observeFix(
        latitude: 41.00834,
        longitude: 28.9784,
        observedAt: DateTime(2026, 1, 2),
        existingPlaces: firstPass,
      );

      expect(secondPass, hasLength(1));
      expect(secondPass.first.visitCount, 2);
      expect(secondPass.first.id, firstPass.first.id);
      // Centroid should land between the two observed points, not jump to
      // the second one outright.
      expect(secondPass.first.latitude, greaterThan(41.0082));
      expect(secondPass.first.latitude, lessThan(41.00834));
    });

    test('observeFix creates a separate place for a fix far from existing '
        'ones', () {
      final firstPlace = engine.observeFix(
        latitude: 41.0082,
        longitude: 28.9784,
        observedAt: DateTime(2026, 1, 1),
        existingPlaces: const [],
      );

      // Roughly 5km away.
      final result = engine.observeFix(
        latitude: 41.05,
        longitude: 28.9784,
        observedAt: DateTime(2026, 1, 2),
        existingPlaces: firstPlace,
      );

      expect(result, hasLength(2));
    });

    test('observeFix does not exceed SignificantPlace.maxPlaces', () {
      var places = <SignificantPlace>[];
      for (var i = 0; i < SignificantPlace.maxPlaces + 5; i++) {
        places = engine.observeFix(
          // Each fix ~1.1km apart (0.01 degrees lat) so none of them merge.
          latitude: 41.0 + (i * 0.01),
          longitude: 28.9784,
          observedAt: DateTime(2026, 1, 1).add(Duration(days: i)),
          existingPlaces: places,
        );
      }

      expect(places.length, SignificantPlace.maxPlaces);
    });

    test('findNearestPlace returns null when nothing is within radius', () {
      final seenAt = DateTime(2026, 1, 1);
      final places = [
        SignificantPlace(
          id: 'p1',
          latitude: 41.0082,
          longitude: 28.9784,
          visitCount: 3,
          firstSeenAt: seenAt,
          lastSeenAt: seenAt,
        ),
      ];

      final match = engine.findNearestPlace(
        latitude: 41.05,
        longitude: 28.9784,
        existingPlaces: places,
      );

      expect(match, isNull);
    });
  });
}
