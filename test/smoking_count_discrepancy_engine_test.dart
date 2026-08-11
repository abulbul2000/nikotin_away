import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/smoking_count_discrepancy_engine.dart';

void main() {
  const engine = SmokingCountDiscrepancyEngine();

  test('gap of exactly the threshold (3) triggers the question', () {
    final result = engine.evaluate(loggedCount: 5, declaredDailyAverage: 8);

    expect(result.gap, 3);
    expect(result.hasDiscrepancy, isTrue);
  });

  test('gap just under the threshold (2) does not trigger the question', () {
    final result = engine.evaluate(loggedCount: 6, declaredDailyAverage: 8);

    expect(result.gap, 2);
    expect(result.hasDiscrepancy, isFalse);
  });

  test('a negative gap (over-logging) never triggers the question', () {
    final result = engine.evaluate(loggedCount: 12, declaredDailyAverage: 8);

    expect(result.gap, -4);
    expect(result.hasDiscrepancy, isFalse);
  });

  test('a gap well above the threshold still triggers the question', () {
    final result = engine.evaluate(loggedCount: 0, declaredDailyAverage: 20);

    expect(result.gap, 20);
    expect(result.hasDiscrepancy, isTrue);
  });

  test('an exact match (gap of zero) does not trigger the question', () {
    final result = engine.evaluate(loggedCount: 10, declaredDailyAverage: 10);

    expect(result.gap, 0);
    expect(result.hasDiscrepancy, isFalse);
  });

  test('carries the raw inputs through unchanged', () {
    final result = engine.evaluate(loggedCount: 4, declaredDailyAverage: 9);

    expect(result.loggedCount, 4);
    expect(result.declaredDailyAverage, 9);
  });
}
