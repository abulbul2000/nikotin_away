import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/wearable_signal_engine.dart';

void main() {
  final engine = WearableSignalEngine();

  group('computeBaselineBpm', () {
    test('returns null for empty samples', () {
      expect(engine.computeBaselineBpm(const []), isNull);
    });

    test('returns the middle value for an odd-length list', () {
      expect(engine.computeBaselineBpm([70, 65, 80]), 70);
    });

    test('averages the two middle values for an even-length list', () {
      expect(engine.computeBaselineBpm([60, 70, 80, 90]), 75);
    });
  });

  group('isElevatedHeartRate', () {
    test('false when baseline is zero or negative', () {
      expect(
        engine.isElevatedHeartRate(latestBpm: 120, baselineBpm: 0),
        isFalse,
      );
    });

    test('false when latest is below baseline', () {
      expect(
        engine.isElevatedHeartRate(latestBpm: 60, baselineBpm: 70),
        isFalse,
      );
    });

    test('false when ratio clears threshold but absolute delta is tiny', () {
      // ratio 1.3 (>=1.25) but delta only 3bpm — a low baseline shouldn't
      // let a trivial bump count as "elevated".
      expect(
        engine.isElevatedHeartRate(latestBpm: 13, baselineBpm: 10),
        isFalse,
      );
    });

    test('false when delta clears minimum but ratio is under threshold', () {
      // baseline 70, latest 85: delta 15 (>=15) but ratio ~1.214 (<1.25).
      expect(
        engine.isElevatedHeartRate(latestBpm: 85, baselineBpm: 70),
        isFalse,
      );
    });

    test('true when both ratio and absolute delta clear their thresholds', () {
      // baseline 70, latest 90: ratio ~1.286, delta 20.
      expect(
        engine.isElevatedHeartRate(latestBpm: 90, baselineBpm: 70),
        isTrue,
      );
    });

    test('respects custom thresholds', () {
      expect(
        engine.isElevatedHeartRate(
          latestBpm: 80,
          baselineBpm: 70,
          thresholdRatio: 1.1,
          minimumDeltaBpm: 5,
        ),
        isTrue,
      );
    });
  });
}
