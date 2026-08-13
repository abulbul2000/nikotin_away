import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/breath_badge_engine.dart';
import 'package:no_smoke/models/breath_badge.dart';
import 'package:no_smoke/models/breath_progress_record.dart';

BreathProgressRecord _record({
  required DateTime completedAt,
  required double breathScore,
  bool isNoisyEnvironment = false,
}) {
  return BreathProgressRecord(
    id: 'r_${completedAt.millisecondsSinceEpoch}',
    completedAt: completedAt,
    breathScore: breathScore,
    blowDurationSeconds: 8,
    blowStability: 0.7,
    blowIntensity: 0.7,
    isNoisyEnvironment: isNoisyEnvironment,
  );
}

void main() {
  group('BreathBadgeEngine.evaluateEarnedKinds', () {
    final engine = BreathBadgeEngine();

    test('empty history earns nothing', () {
      expect(engine.evaluateEarnedKinds(const []), isEmpty);
    });

    test('a single record earns firstTest only', () {
      final earned = engine.evaluateEarnedKinds([
        _record(completedAt: DateTime(2026, 1, 1), breathScore: 50),
      ]);
      expect(earned, {BreathBadgeKind.firstTest});
    });

    test('30 records earn totalTests alongside firstTest', () {
      final base = DateTime(2026, 1, 1);
      final records = List.generate(
        30,
        (i) =>
            _record(completedAt: base.add(Duration(hours: i)), breathScore: 50),
      );
      final earned = engine.evaluateEarnedKinds(records);
      expect(earned, contains(BreathBadgeKind.totalTests));
      expect(earned, contains(BreathBadgeKind.firstTest));
    });

    test('29 records do not yet earn totalTests', () {
      final base = DateTime(2026, 1, 1);
      final records = List.generate(
        29,
        (i) =>
            _record(completedAt: base.add(Duration(hours: i)), breathScore: 50),
      );
      final earned = engine.evaluateEarnedKinds(records);
      expect(earned, isNot(contains(BreathBadgeKind.totalTests)));
    });

    test('7 consecutive calendar days earn dailyStreak', () {
      final base = DateTime(2026, 1, 1);
      final records = List.generate(
        7,
        (i) =>
            _record(completedAt: base.add(Duration(days: i)), breathScore: 50),
      );
      final earned = engine.evaluateEarnedKinds(records);
      expect(earned, contains(BreathBadgeKind.dailyStreak));
    });

    test('7 tests spread across non-consecutive days do not earn '
        'dailyStreak', () {
      final base = DateTime(2026, 1, 1);
      final records = List.generate(
        7,
        (i) => _record(
          completedAt: base.add(Duration(days: i * 2)),
          breathScore: 50,
        ),
      );
      final earned = engine.evaluateEarnedKinds(records);
      expect(earned, isNot(contains(BreathBadgeKind.dailyStreak)));
    });

    test('a score improvement over the first record earns '
        'personalRecord', () {
      final base = DateTime(2026, 1, 1);
      final records = [
        _record(completedAt: base, breathScore: 40),
        _record(
          completedAt: base.add(const Duration(days: 1)),
          breathScore: 60,
        ),
      ];
      final earned = engine.evaluateEarnedKinds(records);
      expect(earned, contains(BreathBadgeKind.personalRecord));
    });

    test('flat or declining scores never earn personalRecord', () {
      final base = DateTime(2026, 1, 1);
      final records = [
        _record(completedAt: base, breathScore: 60),
        _record(
          completedAt: base.add(const Duration(days: 1)),
          breathScore: 50,
        ),
        _record(
          completedAt: base.add(const Duration(days: 2)),
          breathScore: 60,
        ),
      ];
      final earned = engine.evaluateEarnedKinds(records);
      expect(earned, isNot(contains(BreathBadgeKind.personalRecord)));
    });

    test('noisy records are excluded from every badge calculation', () {
      final base = DateTime(2026, 1, 1);
      // 7 consecutive days, but every other one is noisy — should break
      // the clean streak.
      final records = [
        _record(completedAt: base, breathScore: 50),
        _record(
          completedAt: base.add(const Duration(days: 1)),
          breathScore: 90,
          isNoisyEnvironment: true,
        ),
        _record(
          completedAt: base.add(const Duration(days: 2)),
          breathScore: 50,
        ),
      ];
      final earned = engine.evaluateEarnedKinds(records);
      // The noisy record's high score must not count as a personal record.
      expect(earned, isNot(contains(BreathBadgeKind.personalRecord)));
    });
  });
}
