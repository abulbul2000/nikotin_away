import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/core/mentor_command_codes.dart';
import 'package:no_smoke/engines/mentor_engine.dart';

void main() {
  group('MentorEngine.prioritizeTasks', () {
    final engine = MentorEngine();

    test('an empty task list stays empty', () {
      expect(engine.prioritizeTasks(tasks: const [], riskScore: 90), isEmpty);
    });

    test(
      'a postpone-shaped task only outranks others once risk crosses 75',
      () {
        // Alphabetically 'Anka' sorts before 'Zebra' — the postpone bonus
        // is the only way 'Zebra ertele' could ever come first, so this
        // genuinely tests the threshold rather than the tiebreak.
        final tasks = ['Zebra ertele', 'Anka bekle'];

        final belowThreshold = engine.prioritizeTasks(
          tasks: tasks,
          riskScore: 74,
        );
        expect(belowThreshold.first, 'Anka bekle');

        final atThreshold = engine.prioritizeTasks(tasks: tasks, riskScore: 75);
        expect(atThreshold.first, 'Zebra ertele');
      },
    );

    test('a breathing task only scores once risk crosses 60', () {
      final tasks = ['Zebra nefes', 'Anka bekle'];

      final below = engine.prioritizeTasks(tasks: tasks, riskScore: 59);
      expect(below.first, 'Anka bekle');

      final atThreshold = engine.prioritizeTasks(tasks: tasks, riskScore: 60);
      expect(atThreshold.first, 'Zebra nefes');
    });

    test('matching the primary trigger outranks an unrelated task', () {
      final tasks = ['Zebra kahve molası', 'Anka su iç'];

      final withoutTrigger = engine.prioritizeTasks(tasks: tasks, riskScore: 0);
      expect(withoutTrigger.first, 'Anka su iç');

      final withTrigger = engine.prioritizeTasks(
        tasks: tasks,
        riskScore: 0,
        primaryTrigger: 'kahve',
      );
      expect(withTrigger.first, 'Zebra kahve molası');
    });

    test('a riskli saat task only scores once a prediction window exists', () {
      final tasks = ['Zebra riskli saat', 'Anka su iç'];

      final withoutWindow = engine.prioritizeTasks(tasks: tasks, riskScore: 0);
      expect(withoutWindow.first, 'Anka su iç');

      final withWindow = engine.prioritizeTasks(
        tasks: tasks,
        riskScore: 0,
        predictedWindow: '20:00-21:00',
      );
      expect(withWindow.first, 'Zebra riskli saat');
    });

    test('scores stack — matching multiple signals wins outright', () {
      final tasks = ['Kahve molasını ertele', 'Nefes egzersizi yap', 'Su iç'];

      final result = engine.prioritizeTasks(
        tasks: tasks,
        riskScore: 80,
        primaryTrigger: 'kahve',
      );

      // ertele (+3, risk>=75) + kahve trigger match (+2) = 5, beats the
      // breathing task's own +2 (risk>=60, no trigger match) outright.
      expect(result.first, 'Kahve molasını ertele');
    });

    test('a tie in score falls back to alphabetical order', () {
      final tasks = ['Zebra görevi', 'Anka görevi'];

      final result = engine.prioritizeTasks(tasks: tasks, riskScore: 0);

      expect(result, ['Anka görevi', 'Zebra görevi']);
    });
  });

  group('MentorEngine.buildCoachingHints', () {
    final engine = MentorEngine();

    test('risk >= 80 is the high-risk hint', () {
      final hints = engine.buildCoachingHints(
        riskScore: 80,
        predictedWindow: null,
        predictedTrigger: null,
      );
      expect(hints, [MentorCommandCodes.hintHighRisk]);
    });

    test('risk in [60, 80) is the medium-risk hint', () {
      final hints = engine.buildCoachingHints(
        riskScore: 60,
        predictedWindow: null,
        predictedTrigger: null,
      );
      expect(hints, [MentorCommandCodes.hintMedRisk]);
    });

    test('risk below 60 is the low-risk hint', () {
      final hints = engine.buildCoachingHints(
        riskScore: 59,
        predictedWindow: null,
        predictedTrigger: null,
      );
      expect(hints, [MentorCommandCodes.hintLowRisk]);
    });

    test('a predicted window and trigger each add their own hint', () {
      final hints = engine.buildCoachingHints(
        riskScore: 10,
        predictedWindow: '20:00-21:00',
        predictedTrigger: 'kahve',
      );

      expect(hints, [
        MentorCommandCodes.hintLowRisk,
        '${MentorCommandCodes.hintWindowPrefix}:20:00-21:00',
        '${MentorCommandCodes.hintTriggerPrefix}:kahve',
      ]);
    });

    test('never returns more than 3 hints', () {
      final hints = engine.buildCoachingHints(
        riskScore: 90,
        predictedWindow: '20:00-21:00',
        predictedTrigger: 'kahve',
      );

      expect(hints.length, lessThanOrEqualTo(3));
    });
  });

  group('MentorEngine.buildActionCommands', () {
    final engine = MentorEngine();

    List<String> build({
      int riskScore = 10,
      String breathTrend = 'Stable',
      String smokingTrend = 'Stable',
      String consecutiveTrend = 'trendStable',
      int weeklyRiskTarget = 0,
      List<String> riskyHours = const [],
      String? predictedWindow,
      String? predictedTrigger,
      Map<String, dynamic>? weeklyPayload,
    }) {
      return engine.buildActionCommands(
        riskScore: riskScore,
        breathTrend: breathTrend,
        smokingTrend: smokingTrend,
        consecutiveTrend: consecutiveTrend,
        weeklyRiskTarget: weeklyRiskTarget,
        riskyHours: riskyHours,
        predictedWindow: predictedWindow,
        predictedTrigger: predictedTrigger,
        weeklyPayload: weeklyPayload,
      );
    }

    test('the progressive reduction tier scales with risk score', () {
      expect(build(riskScore: 80).first, MentorCommandCodes.reductionTier75);
      expect(build(riskScore: 60).first, MentorCommandCodes.reductionTier60);
      expect(build(riskScore: 40).first, MentorCommandCodes.reductionTier40);
      expect(build(riskScore: 0).first, MentorCommandCodes.reductionTierBase);
    });

    test('breath trend maps to exactly the matching canonical code', () {
      expect(
        build(breathTrend: 'Declining'),
        contains(MentorCommandCodes.breathDeclining),
      );
      expect(
        build(breathTrend: 'Improving'),
        contains(MentorCommandCodes.breathImproving),
      );
      expect(
        build(breathTrend: 'Stable'),
        contains(MentorCommandCodes.breathStable),
      );
    });

    test(
      'the smoking/consecutive-trend track command is built unconditionally, '
      'but the 4-command cap means it can never actually be selected',
      () {
        // Documents real, current behavior rather than the intent the
        // branch reads as: buildActionCommands always adds, in order,
        // reduction (1) + two riskDaypart commands (2) + breathTrend (1)
        // = 4 distinct commands before the smoking/consecutive-trend
        // branch is even reached. Since those four are always present and
        // always distinct (riskDaypartId embeds a 0/1 index, so the pair
        // never collides), `unique.take(4)` fills up before track/window/
        // trigger/riskyHours/weeklyTarget get a turn — none of those five
        // signal types can currently reach the returned list under any
        // input. Whether that's the intended priority order (reduction +
        // daypart context should always outrank a situational nudge) or a
        // latent bug (the more personalized signals never get shown) is a
        // product call, not something to silently change here.
        expect(
          build(smokingTrend: 'Increasing'),
          isNot(contains(MentorCommandCodes.trackReduceToday)),
        );
        expect(
          build(consecutiveTrend: 'trendDeclining'),
          isNot(contains(MentorCommandCodes.trackReduceToday)),
        );
        expect(
          build(smokingTrend: 'Stable', consecutiveTrend: 'trendStable'),
          isNot(contains(MentorCommandCodes.trackCompleteThree)),
        );
      },
    );

    test('a predicted window/trigger, a risky hour, and a weekly target are '
        'likewise built but never selected, for the same reason', () {
      expect(
        build(predictedWindow: '20:00-21:00', predictedTrigger: 'kahve'),
        allOf(
          isNot(contains('${MentorCommandCodes.prepWindowPrefix}:20:00-21:00')),
          isNot(contains('${MentorCommandCodes.triggerDelayPrefix}:kahve')),
        ),
      );
      expect(
        build(riskyHours: const ['20:00-22:00', '08:00-09:00']),
        isNot(
          contains('${MentorCommandCodes.focusRiskHourPrefix}:20:00-22:00'),
        ),
      );
      expect(
        build(weeklyRiskTarget: 15),
        isNot(contains('${MentorCommandCodes.weeklyTargetPrefix}:15')),
      );
    });

    test('never returns more than 4 commands', () {
      final commands = build(
        riskScore: 90,
        breathTrend: 'Declining',
        smokingTrend: 'Increasing',
        predictedWindow: '20:00-21:00',
        predictedTrigger: 'kahve',
        riskyHours: const ['20:00-22:00'],
        weeklyRiskTarget: 15,
      );

      expect(commands.length, lessThanOrEqualTo(4));
    });

    test('a low command-burden preference softens every selected command', () {
      final commands = build(
        weeklyPayload: {
          'task': {'commandBurdenLevel': 'cok'},
        },
      );

      for (final command in commands) {
        expect(command, endsWith(MentorCommandCodes.toneSoftSuffix));
      }
    });

    test(
      'a high command-burden preference sharpens every selected command',
      () {
        final commands = build(
          weeklyPayload: {
            'task': {'commandBurdenLevel': 'az'},
          },
        );

        for (final command in commands) {
          expect(command, endsWith(MentorCommandCodes.toneActiveSuffix));
        }
      },
    );

    test('a moderate burden preference leaves commands untoned', () {
      final commands = build(
        weeklyPayload: {
          'task': {'commandBurdenLevel': 'orta'},
        },
      );

      for (final command in commands) {
        expect(command, isNot(endsWith(MentorCommandCodes.toneSoftSuffix)));
        expect(command, isNot(endsWith(MentorCommandCodes.toneActiveSuffix)));
      }
    });

    test(
      'heavy trigger exposure in the weekly payload adds the matching trigger command',
      () {
        final commands = build(
          weeklyPayload: {
            'triggerExposureDays': {'stress': 5},
          },
        );

        expect(commands, contains(MentorCommandCodes.triggerStress));
      },
    );

    test('a high lapse count or craving peak triggers the crisis protocol', () {
      final commands = build(weeklyPayload: {'lapseCount': 2});
      expect(commands, contains(MentorCommandCodes.crisisProtocol));

      final commandsFromCraving = build(weeklyPayload: {'cravingMax': 8});
      expect(commandsFromCraving, contains(MentorCommandCodes.crisisProtocol));
    });

    test('low self-efficacy or motivation asks for a single support goal', () {
      final commands = build(weeklyPayload: {'selfEfficacy': 3});
      expect(commands, contains(MentorCommandCodes.supportSingleGoal));
    });
  });
}
