import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/behavior_engine.dart';

/// A payload shaped like the one the reworked survey submits.
Map<String, dynamic> payload({
  int avgCigarettes = 10,
  String delta = 'same',
  int lapseCount = 0,
  int cravingPeak = 5,
  List<String> withdrawal = const [],
  List<String> triggers = const [],
  int selfEfficacy = 6,
  int motivation = 7,
  int completion = 6,
  int mmrcGrade = 0,
  Map<String, dynamic>? catLike,
  int nightBreathlessness = 0,
}) {
  return {
    'avgCigarettesPerDay': avgCigarettes,
    'deltaVsLastWeek': delta,
    'lapseCount': lapseCount,
    'cravingPeak': cravingPeak,
    'withdrawal': withdrawal,
    'triggers': triggers,
    'selfEfficacy': selfEfficacy,
    'motivation': motivation,
    'task': {'weeklyCompletionRate': completion},
    'respiratory': {
      'mmrcGrade': mmrcGrade,
      'catLike':
          catLike ??
          const {
            'cough': 0,
            'breathlessnessStairs': 0,
            'sleepQualityResp': 0,
            'energyLevelResp': 0,
          },
      'warningSigns': {
        'increasedNightBreathlessnessDays': nightBreathlessness,
      },
    },
  };
}

int scoreOf(Map<String, dynamic> input) {
  final result = BehaviorEngine().evaluateWeeklySurveyRisk(input);
  return (result['weeklyRiskScore'] as num).toInt();
}

void main() {
  group('withdrawal', () {
    test('reporting nothing scores lower than reporting everything', () {
      final none = scoreOf(payload());
      final all = scoreOf(
        payload(
          withdrawal: const [
            'irritability',
            'anxiety',
            'sleepProblem',
            'concentrationProblem',
            'appetiteIncrease',
          ],
        ),
      );

      expect(all, greaterThan(none));
    });

    test('each symptom moves the score, so the answer is not decorative', () {
      final one = scoreOf(payload(withdrawal: const ['anxiety']));
      final three = scoreOf(
        payload(withdrawal: const ['anxiety', 'sleepProblem', 'irritability']),
      );

      expect(three, greaterThan(one));
    });
  });

  group('triggers', () {
    test('more triggers means more risk', () {
      final few = scoreOf(payload(triggers: const ['coffee']));
      final many = scoreOf(
        payload(triggers: const ['coffee', 'meal', 'driving', 'phone']),
      );

      expect(many, greaterThan(few));
    });

    test('stress and alcohol weigh more than the rest', () {
      // Same number of triggers, different ones.
      final mild = scoreOf(payload(triggers: const ['coffee', 'meal']));
      final heavy = scoreOf(payload(triggers: const ['stress', 'alcohol']));

      expect(heavy, greaterThan(mild));
    });

    test('alcohol and social answers stand in for the day counts', () {
      // `alcoholDays` and `socialSmokingContextDays` were separate fields the
      // survey filled in with constants. The trigger answers now carry that
      // weight without a question of their own.
      final without = scoreOf(payload(triggers: const ['coffee']));
      final with_ = scoreOf(payload(triggers: const ['alcohol', 'social']));

      expect(with_, greaterThan(without));
    });
  });

  group('old records', () {
    test('a pre-rework payload still scores instead of reading as zero', () {
      // Surveys already in the database hold maps of key → severity/days.
      // Dropping them to zero would rewrite the user's history as symptom-free.
      final legacy = payload()
        ..['withdrawal'] = {
          'irritability': 2,
          'anxiety': 2,
          'sleepProblem': 0,
          'concentrationProblem': 0,
          'appetiteIncrease': 0,
        }
        ..['triggers'] = {'coffee': 3, 'stress': 5, 'meal': 0};

      final legacyScore = scoreOf(legacy);
      final equivalent = scoreOf(
        payload(
          withdrawal: const ['irritability', 'anxiety'],
          triggers: const ['coffee', 'stress'],
        ),
      );

      expect(legacyScore, equivalent);
    });
  });

  group('respiratory', () {
    test('leaving mMRC at the default does not report breathlessness', () {
      // The control used to open at grade 2 and clamp from 1, so an untouched
      // survey scored as "walks slower than people my age".
      final untouched = scoreOf(payload(mmrcGrade: 0));
      final mild = scoreOf(payload(mmrcGrade: 1));

      expect(untouched, lessThan(mild));
    });

    test('the burden averages over answered items only', () {
      // Four items answered at 5 is maximum burden. It used to divide by
      // eight regardless, so answering every question you were shown could
      // still only reach half the scale.
      final maxed = BehaviorEngine().evaluateWeeklySurveyRisk(
        payload(
          catLike: const {
            'cough': 5,
            'breathlessnessStairs': 5,
            'sleepQualityResp': 5,
            'energyLevelResp': 5,
          },
        ),
      );

      expect((maxed['respiratoryBurden'] as num).toInt(), greaterThan(40));
    });

    test('an empty respiratory section contributes nothing', () {
      final result = BehaviorEngine().evaluateWeeklySurveyRisk(
        payload(catLike: const {}),
      );

      expect((result['respiratoryBurden'] as num).toInt(), 0);
    });
  });

  group('plan adherence', () {
    test('answered tasks lower the score, ignored ones raise it', () {
      final good = scoreOf(payload(completion: 10));
      final poor = scoreOf(payload(completion: 0));

      // Medication adherence used to be 40% of this component and was never
      // asked — the survey filled it in at 7 or 8 regardless.
      expect(poor, greaterThan(good));
    });
  });

  group('escalation', () {
    test('repeated lapses with a hard peak escalate the mode', () {
      final result = BehaviorEngine().evaluateWeeklySurveyRisk(
        payload(lapseCount: 4, cravingPeak: 9),
      );

      expect(result['recommendedMode'], 'aggressive');
    });

    test('a clean week with high confidence turns protective', () {
      final result = BehaviorEngine().evaluateWeeklySurveyRisk(
        payload(
          avgCigarettes: 3,
          lapseCount: 0,
          selfEfficacy: 9,
          motivation: 9,
          completion: 9,
          cravingPeak: 2,
        ),
      );

      expect(result['recommendedMode'], 'protective');
    });
  });
}
