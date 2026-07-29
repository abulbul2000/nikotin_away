import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/achievement.dart';
import 'package:no_smoke/models/reduction_progress.dart';
import 'package:no_smoke/services/achievement_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

ReductionProgress progressWith({
  int streak = 0,
  int avoided = 0,
  int natural = 40,
  int barrier = 40,
}) {
  return ReductionProgress(
    targetStreakDays: streak,
    cigarettesAvoided: avoided,
    naturalIntervalMinutes: natural,
    currentBarrierMinutes: barrier,
    dailyTarget: 10,
    baselineDaily: 20,
    loggedToday: null,
    evidenceDays: streak,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('a fresh install with no progress unlocks nothing', () async {
    final unlocked = await AchievementService().evaluateProgress(
      progressWith(),
    );

    // The old catalog keyed off days since the quit date, so an install that
    // sat untouched for a week handed out three badges.
    expect(unlocked, isEmpty);
  });

  test('a day on target unlocks the first streak badge only', () async {
    final unlocked = await AchievementService().evaluateProgress(
      progressWith(streak: 1),
    );

    expect(unlocked.map((a) => a.id), ['streak_1']);
  });

  test('badges already earned are not handed out twice', () async {
    final service = AchievementService();
    await service.evaluateProgress(progressWith(streak: 3));

    final second = await service.evaluateProgress(progressWith(streak: 3));
    expect(second, isEmpty);

    final all = await service.loadAll();
    expect(all.where((a) => a.unlocked).map((a) => a.id), [
      'streak_1',
      'streak_3',
    ]);
  });

  test('cigarettes avoided unlock on their own axis', () async {
    final unlocked = await AchievementService().evaluateProgress(
      progressWith(avoided: 120),
    );

    // Someone who logs faithfully but has never strung two days together
    // still has something to show for it.
    expect(unlocked.map((a) => a.id), ['avoided_20', 'avoided_100']);
  });

  test('a widened interval unlocks on percentage gained', () async {
    // 40 → 52 minutes is a 30% gain: past the first threshold, short of the
    // second.
    final unlocked = await AchievementService().evaluateProgress(
      progressWith(natural: 40, barrier: 52),
    );

    expect(unlocked.map((a) => a.id), ['interval_25']);
  });

  test('a big jump unlocks every threshold it passed', () async {
    final unlocked = await AchievementService().evaluateProgress(
      progressWith(natural: 40, barrier: 60),
    );

    // Half again as long clears both the 25% and 50% marks, and someone
    // arriving there after a break should not have to re-earn the one they
    // passed on the way.
    expect(unlocked.map((a) => a.id), ['interval_25', 'interval_50']);
  });

  test('a barrier at the natural gap earns no interval badge', () async {
    final unlocked = await AchievementService().evaluateProgress(
      progressWith(natural: 40, barrier: 40),
    );

    expect(unlocked, isEmpty);
  });

  test('currentValueFor reports the figure each badge is judged on', () {
    final progress = progressWith(
      streak: 4,
      avoided: 88,
      natural: 40,
      barrier: 80,
    );

    expect(
      AchievementService.currentValueFor(
        AchievementKind.targetStreak,
        progress,
      ),
      4,
    );
    expect(
      AchievementService.currentValueFor(
        AchievementKind.cigarettesAvoided,
        progress,
      ),
      88,
    );
    expect(
      AchievementService.currentValueFor(
        AchievementKind.intervalGain,
        progress,
      ),
      100,
    );
  });

  test('every badge in the catalog has a distinct id', () {
    final ids = Achievement.catalog.map((a) => a.id).toSet();
    expect(ids, hasLength(Achievement.catalog.length));
  });
}
