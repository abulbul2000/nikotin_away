import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/breath_test_gate.dart';

void main() {
  const gate = BreathTestGate();
  final now = DateTime(2026, 7, 30, 14, 0);

  test('a reading taken today asks for nothing', () {
    final standing = gate.standing(
      lastCompletedAt: DateTime(2026, 7, 30, 8, 0),
      now: now,
    );

    expect(standing, BreathTestStanding.doneToday);
    expect(
      gate.shouldPrompt(lastCompletedAt: DateTime(2026, 7, 30, 8, 0), now: now),
      isFalse,
    );
  });

  test('yesterday evening is due, and may be put off', () {
    final lastNight = DateTime(2026, 7, 29, 22, 0);

    expect(
      gate.standing(lastCompletedAt: lastNight, now: now),
      BreathTestStanding.due,
    );
    expect(gate.canDefer(lastCompletedAt: lastNight, now: now), isTrue);
  });

  test('a full day without a reading cannot be put off', () {
    final twoDaysAgo = DateTime(2026, 7, 28, 9, 0);

    // The trend the whole programme reports on is built from these, and a
    // gap in it cannot be filled in afterwards.
    expect(
      gate.standing(lastCompletedAt: twoDaysAgo, now: now),
      BreathTestStanding.overdue,
    );
    expect(gate.canDefer(lastCompletedAt: twoDaysAgo, now: now), isFalse);
  });

  test('a reading twenty minutes before midnight is not overdue after it', () {
    // Elapsed time, not "the date changed". Testing at 23:50 and opening the
    // app at 00:10 skips nothing, and being told otherwise would read as the
    // app losing track.
    final lateLastNight = DateTime(2026, 7, 29, 23, 50);
    final justAfterMidnight = DateTime(2026, 7, 30, 0, 10);

    expect(
      gate.standing(
        lastCompletedAt: lateLastNight,
        now: justAfterMidnight,
      ),
      BreathTestStanding.due,
    );
    expect(
      gate.canDefer(lastCompletedAt: lateLastNight, now: justAfterMidnight),
      isTrue,
    );
  });

  test('exactly twenty-four hours is already overdue', () {
    final exactly = now.subtract(const Duration(hours: 24));

    expect(
      gate.standing(lastCompletedAt: exactly, now: now),
      BreathTestStanding.overdue,
    );
  });

  test('someone who has never taken one is asked without a way out', () {
    // No trend to protect yet — but also nothing to build one from, so
    // deferring for ever is the one outcome to rule out.
    expect(
      gate.standing(lastCompletedAt: null, now: now),
      BreathTestStanding.overdue,
    );
    expect(gate.canDefer(lastCompletedAt: null, now: now), isFalse);
    expect(gate.shouldPrompt(lastCompletedAt: null, now: now), isTrue);
  });
}
