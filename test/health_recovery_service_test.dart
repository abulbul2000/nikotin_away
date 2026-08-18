import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/health_milestone.dart';
import 'package:no_smoke/services/health_recovery_service.dart';

void main() {
  final service = HealthRecoveryService();

  group('HealthRecoveryService.computeProgress', () {
    test('no evidence (null lastSmokedAt) reports nothing reached', () {
      // Regression coverage: computeProgress used to take a non-nullable
      // quitDate and measure elapsed time from it unconditionally — a
      // brand-new user or one who never logged a cigarette would still
      // see milestones "reached" purely from wall-clock time since some
      // arbitrary date, in a product that is gradual reduction, not
      // abstinence (see CLAUDE.md). Silence must not read as achievement.
      final progress = service.computeProgress(null);

      expect(progress.reached, isEmpty);
      expect(progress.next, isNull);
      expect(progress.nextProgress, 0);
    });

    test(
      'a cigarette logged just now has reached nothing and is partway to the first milestone',
      () {
        final progress = service.computeProgress(DateTime.now());

        expect(progress.reached, isEmpty);
        expect(progress.next?.titleKey, 'recoveryMin20Title');
        expect(progress.nextProgress, closeTo(0, 0.05));
      },
    );

    test(
      'elapsed time is measured from the last cigarette, not a fixed quit date',
      () {
        // 30 minutes since the last logged cigarette crosses the 20-minute
        // milestone but not the 12-hour one.
        final lastSmokedAt = DateTime.now().subtract(
          const Duration(minutes: 30),
        );
        final progress = service.computeProgress(lastSmokedAt);

        expect(
          progress.reached.map((m) => m.titleKey),
          contains('recoveryMin20Title'),
        );
        expect(
          progress.reached.map((m) => m.titleKey),
          isNot(contains('recoveryHour12Title')),
        );
        expect(progress.next?.titleKey, 'recoveryHour12Title');
      },
    );

    test(
      'every milestone in the timeline is reached given enough elapsed time',
      () {
        final lastSmokedAt = DateTime.now().subtract(
          const Duration(days: 3651),
        );
        final progress = service.computeProgress(lastSmokedAt);

        expect(progress.reached.length, HealthMilestone.timeline.length);
        expect(progress.next, isNull);
      },
    );

    test(
      'nextProgress is the fraction of the way from the previous milestone to the next one',
      () {
        // Halfway between the 20-minute and 12-hour milestones.
        final span = const Duration(hours: 12) - const Duration(minutes: 20);
        final lastSmokedAt = DateTime.now().subtract(
          const Duration(minutes: 20) +
              Duration(microseconds: span.inMicroseconds ~/ 2),
        );
        final progress = service.computeProgress(lastSmokedAt);

        expect(progress.next?.titleKey, 'recoveryHour12Title');
        expect(progress.nextProgress, closeTo(0.5, 0.05));
      },
    );
  });
}
