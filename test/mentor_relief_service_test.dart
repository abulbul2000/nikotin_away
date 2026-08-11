import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/mentor_relief_service.dart';

void main() {
  group('applyTaskReliefIfActive', () {
    test('no relief granted (reliefUntil null) leaves the count unchanged', () {
      final result = MentorReliefService.applyTaskReliefIfActive(
        baseCount: 4,
        now: DateTime(2026, 1, 5),
        reliefUntil: null,
      );
      expect(result, 4);
    });

    test('active relief halves the count, rounding up', () {
      final result = MentorReliefService.applyTaskReliefIfActive(
        baseCount: 5,
        now: DateTime(2026, 1, 5),
        reliefUntil: DateTime(2026, 1, 10),
      );
      expect(result, 3); // ceil(5 * 0.5) = 3
    });

    test('active relief never drops below 1', () {
      final result = MentorReliefService.applyTaskReliefIfActive(
        baseCount: 1,
        now: DateTime(2026, 1, 5),
        reliefUntil: DateTime(2026, 1, 10),
      );
      expect(result, 1);
    });

    test('expired relief (now on or after reliefUntil) leaves the count unchanged', () {
      final result = MentorReliefService.applyTaskReliefIfActive(
        baseCount: 4,
        now: DateTime(2026, 1, 10),
        reliefUntil: DateTime(2026, 1, 10),
      );
      expect(result, 4);
    });

    test('the instant before reliefUntil is still active', () {
      final result = MentorReliefService.applyTaskReliefIfActive(
        baseCount: 4,
        now: DateTime(2026, 1, 9, 23, 59, 59),
        reliefUntil: DateTime(2026, 1, 10),
      );
      expect(result, 2);
    });
  });

  group('applyBarrierReliefIfActive', () {
    test('no relief granted (reliefDate null) leaves the minutes unchanged', () {
      final result = MentorReliefService.applyBarrierReliefIfActive(
        baseMinutes: 30,
        now: DateTime(2026, 1, 5, 14, 0),
        reliefDate: null,
        minBarrierMinutes: 10,
      );
      expect(result, 30);
    });

    test('relief dated today (any time of day) is active', () {
      final result = MentorReliefService.applyBarrierReliefIfActive(
        baseMinutes: 30,
        now: DateTime(2026, 1, 5, 23, 0),
        reliefDate: DateTime(2026, 1, 5, 0, 0),
        minBarrierMinutes: 10,
      );
      expect(result, 21); // round(30 * 0.7) = 21
    });

    test('relief dated a different day is inactive', () {
      final result = MentorReliefService.applyBarrierReliefIfActive(
        baseMinutes: 30,
        now: DateTime(2026, 1, 6, 0, 0, 1),
        reliefDate: DateTime(2026, 1, 5, 23, 59),
        minBarrierMinutes: 10,
      );
      expect(result, 30);
    });

    test('active relief clamps above minBarrierMinutes', () {
      final result = MentorReliefService.applyBarrierReliefIfActive(
        baseMinutes: 12,
        now: DateTime(2026, 1, 5, 10, 0),
        reliefDate: DateTime(2026, 1, 5),
        minBarrierMinutes: 10,
      );
      // round(12 * 0.7) = 8, clamped up to 10.
      expect(result, 10);
    });
  });
}
