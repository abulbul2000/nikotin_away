import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/respiratory_burden_engine.dart';

Map<String, dynamic> _payload({
  int mmrcGrade = 1,
  Map<String, int> catLike = const {},
  Map<String, int> warningSigns = const {},
}) {
  return {
    'respiratory': {
      'mmrcGrade': mmrcGrade,
      'catLike': catLike,
      'warningSigns': warningSigns,
    },
  };
}

void main() {
  group('RespiratoryBurdenEngine.calculateBurden', () {
    test('the lowest possible inputs score 0', () {
      final payload = _payload(
        mmrcGrade: 1,
        catLike: const {},
        warningSigns: const {},
      );
      expect(RespiratoryBurdenEngine.calculateBurden(payload), 0);
    });

    test('the highest possible inputs score 100', () {
      final payload = _payload(
        mmrcGrade: 5,
        catLike: const {
          'cough': 5,
          'phlegm': 5,
          'chestTightness': 5,
          'breathlessnessStairs': 5,
          'activityLimitation': 5,
          'confidenceLeavingHome': 5,
          'sleepQualityResp': 5,
          'energyLevelResp': 5,
        },
        warningSigns: const {
          'increasedNightBreathlessnessDays': 7,
          'sputumIncreaseDays': 7,
          'sputumColorChangeDays': 7,
          'wheezeDays': 7,
        },
      );
      expect(RespiratoryBurdenEngine.calculateBurden(payload), 100);
    });

    test('the 0.35/0.45/0.20 weighting matches the closed-form value', () {
      // mmrcComponent = (3-1)/4*100 = 50, catComponent = 20/40*100 = 50,
      // warningComponent = 14/28*100 = 50 -> every component is 50, so the
      // weighted sum is 50 regardless of the weights themselves. Use
      // unequal components instead to actually exercise the weights.
      final payload = _payload(
        mmrcGrade: 5, // mmrcComponent = 100
        catLike: const {'cough': 0}, // catComponent = 0
        warningSigns: const {}, // warningComponent = 0
      );
      // 0.35*100 + 0.45*0 + 0.20*0 = 35
      expect(RespiratoryBurdenEngine.calculateBurden(payload), 35);
    });

    test('missing fields score as 0 rather than throwing', () {
      expect(RespiratoryBurdenEngine.calculateBurden(const {}), 0);
    });
  });

  group('RespiratoryBurdenEngine.resolveState', () {
    test('a burden at or above 65 is clinical_review_recommended', () {
      // mmrc alone (grade 5) scores 35 — not enough on its own. Adding CAT
      // symptoms pushes the weighted total over 65.
      final moderateOnly = _payload(mmrcGrade: 5);
      final highBurden = _payload(
        mmrcGrade: 5,
        catLike: const {
          'cough': 5,
          'phlegm': 5,
          'chestTightness': 5,
          'breathlessnessStairs': 5,
          'activityLimitation': 5,
          'confidenceLeavingHome': 5,
          'sleepQualityResp': 5,
          'energyLevelResp': 5,
        },
      );
      expect(
        RespiratoryBurdenEngine.resolveState(moderateOnly),
        isNot('clinical_review_recommended'),
      );
      expect(
        RespiratoryBurdenEngine.resolveState(highBurden),
        'clinical_review_recommended',
      );
    });

    test('a severe combo forces clinical_review_recommended even under 65', () {
      // mmrc 4 + 4 nights of breathlessness, everything else at 0 keeps the
      // weighted burden well under 65.
      final payload = _payload(
        mmrcGrade: 4,
        warningSigns: const {'increasedNightBreathlessnessDays': 4},
      );
      expect(RespiratoryBurdenEngine.calculateBurden(payload), lessThan(65));
      expect(
        RespiratoryBurdenEngine.resolveState(payload),
        'clinical_review_recommended',
      );
    });

    test('a burden at or above 35 without severe signs is monitor_closer', () {
      final payload = _payload(mmrcGrade: 5); // burden = 35
      expect(RespiratoryBurdenEngine.resolveState(payload), 'monitor_closer');
    });

    test('low burden and no warning signs is stable', () {
      final payload = _payload(mmrcGrade: 1);
      expect(RespiratoryBurdenEngine.resolveState(payload), 'stable');
    });
  });

  group('RespiratoryBurdenEngine.snapshot', () {
    test('bundles burden, state and the raw component totals together', () {
      final payload = _payload(
        mmrcGrade: 3,
        catLike: const {'cough': 4, 'phlegm': 2},
        warningSigns: const {'wheezeDays': 3},
      );
      final snapshot = RespiratoryBurdenEngine.snapshot(payload);

      expect(
        snapshot['burden'],
        RespiratoryBurdenEngine.calculateBurden(payload),
      );
      expect(snapshot['state'], RespiratoryBurdenEngine.resolveState(payload));
      expect(snapshot['mmrc'], 3);
      expect(snapshot['catTotal'], 6);
      expect(snapshot['warningTotal'], 3);
    });
  });

  group('RespiratoryBurdenEngine.resolveEffectiveDailyBreathTarget', () {
    test('a burden at or above 65 adds one test on top of the base target', () {
      final highBurden = _payload(
        mmrcGrade: 5,
        catLike: const {
          'cough': 5,
          'phlegm': 5,
          'chestTightness': 5,
          'breathlessnessStairs': 5,
          'activityLimitation': 5,
          'confidenceLeavingHome': 5,
          'sleepQualityResp': 5,
          'energyLevelResp': 5,
        },
      );
      expect(
        RespiratoryBurdenEngine.calculateBurden(highBurden),
        greaterThanOrEqualTo(65),
      );
      expect(
        RespiratoryBurdenEngine.resolveEffectiveDailyBreathTarget(
          highBurden,
          1,
        ),
        2,
      );
    });

    test('a burden under 65 leaves the base target untouched', () {
      final payload = _payload(mmrcGrade: 1);
      expect(
        RespiratoryBurdenEngine.resolveEffectiveDailyBreathTarget(payload, 1),
        1,
      );
    });

    test('the bump never pushes the target past 4', () {
      final highBurden = _payload(
        mmrcGrade: 5,
        catLike: const {
          'cough': 5,
          'phlegm': 5,
          'chestTightness': 5,
          'breathlessnessStairs': 5,
          'activityLimitation': 5,
          'confidenceLeavingHome': 5,
          'sleepQualityResp': 5,
          'energyLevelResp': 5,
        },
      );
      expect(
        RespiratoryBurdenEngine.resolveEffectiveDailyBreathTarget(
          highBurden,
          4,
        ),
        4,
      );
    });
  });
}
