import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/smoking_time_prediction_engine.dart';
import 'package:no_smoke/models/smoking_time_prediction.dart';

void main() {
  final engine = SmokingTimePredictionEngine();

  test('zeroes out the sleep window', () {
    final prediction = engine.predict(
      profileContext: const {'sleepTime': '23:00', 'wakeTime': '07:00'},
      packsPerDay: '1 paket',
    );

    for (final hour in [23, 0, 1, 2, 3, 4, 5, 6]) {
      expect(
        prediction.slotForHour(hour).weight,
        0,
        reason: 'hour $hour should be within the sleep window',
      );
    }
    expect(prediction.slotForHour(12).weight, greaterThan(0));
  });

  test('anchors a peak shortly after waking based on firstCigaretteRange', () {
    final prediction = engine.predict(
      profileContext: const {
        'sleepTime': '23:00',
        'wakeTime': '07:00',
        'firstCigaretteRange': '0-5',
      },
      packsPerDay: '1 paket',
    );

    // 07:00 + ~3 minutes still rounds to hour 7.
    final wakeHourWeight = prediction.slotForHour(7).weight;
    final middayWeight = prediction.slotForHour(14).weight;
    expect(wakeHourWeight, greaterThan(middayWeight));
  });

  test(
    'suppresses work hours and boosts the hour work ends when smoking is not allowed at work',
    () {
      final prediction = engine.predict(
        profileContext: const {
          'sleepTime': '23:00',
          'wakeTime': '07:00',
          'workStart': '09:00',
          'workEnd': '17:00',
          'workplaceSmokingRule': 'Hayır',
        },
        packsPerDay: '1 paket',
      );

      final duringWork = prediction.slotForHour(12).weight;
      final afterWork = prediction.slotForHour(17).weight;
      expect(afterWork, greaterThan(duringWork));
    },
  );

  test('boosts break windows when smoking is restricted to breaks', () {
    final prediction = engine.predict(
      profileContext: const {
        'sleepTime': '23:00',
        'wakeTime': '07:00',
        'workStart': '09:00',
        'workEnd': '17:00',
        'workplaceSmokingRule': 'Sadece molalarda',
        'breakWindows': [
          {'start': '11:00', 'end': '11:15'},
        ],
      },
      packsPerDay: '1 paket',
    );

    final breakHour = prediction.slotForHour(11).weight;
    final otherWorkHour = prediction.slotForHour(13).weight;
    expect(breakHour, greaterThan(otherWorkHour));
  });

  test(
    'estimated cigarette counts across all 24 hours sum to the daily total',
    () {
      final prediction = engine.predict(
        profileContext: const {'sleepTime': '23:00', 'wakeTime': '07:00'},
        packsPerDay: '2 paket',
      );

      final total = prediction.hourly.fold<int>(
        0,
        (sum, slot) => sum + slot.estimatedCigarettes,
      );
      expect(
        total,
        40,
      ); // '2 paket' -> 40 cigarettes/day (packsToLegacyCigarettes)
    },
  );

  test('confidence increases when weekly survey data is available', () {
    final structuralOnly = engine.predict(
      profileContext: const {'sleepTime': '23:00', 'wakeTime': '07:00'},
      packsPerDay: '1 paket',
    );
    final withWeekly = engine.predict(
      profileContext: const {
        'sleepTime': '23:00',
        'wakeTime': '07:00',
        'weeklyPayload': {
          'triggerExposureDays': {'meal': 5},
        },
      },
      packsPerDay: '1 paket',
    );

    expect(withWeekly.confidence, greaterThan(structuralOnly.confidence));
    expect(structuralOnly.basis, 'structural');
    expect(withWeekly.basis, 'structural+weekly');
  });

  test('gracefully handles completely empty profile context', () {
    final prediction = engine.predict(
      profileContext: const {},
      packsPerDay: '1 paketten az',
    );

    expect(prediction.hourly, hasLength(24));
    final total = prediction.hourly.fold<double>(
      0,
      (sum, slot) => sum + slot.weight,
    );
    expect(total, closeTo(1.0, 0.01));
  });

  test('uses cigarettesPerPack for the daily total when provided', () {
    final prediction = engine.predict(
      profileContext: const {
        'sleepTime': '23:00',
        'wakeTime': '07:00',
        'cigarettesPerPack': 25,
      },
      packsPerDay: '2 paket',
    );

    final total = prediction.hourly.fold<int>(
      0,
      (sum, slot) => sum + slot.estimatedCigarettes,
    );
    expect(total, 50); // 2 packs * 25/pack, not the legacy 20/pack default
  });

  test('averageMinutesBetweenCigarettes is null without sleep/wake data', () {
    final prediction = engine.predict(
      profileContext: const {},
      packsPerDay: '1 paket',
    );

    expect(prediction.averageMinutesBetweenCigarettes, isNull);
  });

  test(
    'averageMinutesBetweenCigarettes spreads smokable minutes evenly, no work restriction',
    () {
      final prediction = engine.predict(
        profileContext: const {
          'sleepTime': '23:00',
          'wakeTime': '07:00',
          'cigarettesPerPack': 20,
        },
        packsPerDay: '1 paket', // 20 cigarettes/day
      );

      // Awake window: 24h - 8h sleep = 16h = 960 minutes; 960 / 20 = 48.
      expect(prediction.averageMinutesBetweenCigarettes, 48);
    },
  );

  test(
    'averageMinutesBetweenCigarettes shrinks the window when smoking is not allowed at work',
    () {
      final prediction = engine.predict(
        profileContext: const {
          'sleepTime': '23:00',
          'wakeTime': '07:00',
          'workStart': '09:00',
          'workEnd': '17:00',
          'workplaceSmokingRule': 'Hayır',
          'cigarettesPerPack': 20,
        },
        packsPerDay: '1 paket', // 20 cigarettes/day
      );

      // Awake 960 min - 8h work (480 min) = 480 min smokable; 480 / 20 = 24.
      expect(prediction.averageMinutesBetweenCigarettes, 24);
    },
  );

  test(
    'averageMinutesBetweenCigarettes only credits break windows when break-restricted',
    () {
      final prediction = engine.predict(
        profileContext: const {
          'sleepTime': '23:00',
          'wakeTime': '07:00',
          'workStart': '09:00',
          'workEnd': '17:00',
          'workplaceSmokingRule': 'Sadece molalarda',
          'breakWindows': [
            {'start': '11:00', 'end': '11:15'},
            {'start': '15:00', 'end': '15:15'},
          ],
          'cigarettesPerPack': 20,
        },
        packsPerDay: '1 paket', // 20 cigarettes/day
      );

      // Awake 960 min - (480 min work - 30 min breaks) = 510 min smokable.
      // 510 / 20 = 25.5 -> rounds to 26.
      expect(prediction.averageMinutesBetweenCigarettes, 26);
    },
  );

  group('calibration against logged events', () {
    SmokingTimePrediction structuralPrior() => engine.predict(
      profileContext: const {
        'sleepTime': '23:00',
        'wakeTime': '07:00',
        'workStart': '09:00',
        'workEnd': '17:00',
        'workplaceSmokingRule': 'Evet',
      },
      packsPerDay: '1 paket',
    );

    List<DateTime> loggedAt(int hour, int count) => List.generate(
      count,
      (i) => DateTime(2026, 7, 1).add(Duration(days: i, hours: hour)),
    );

    test('nothing logged leaves the prior untouched', () {
      final prior = structuralPrior();

      final calibrated = engine.calibrateWithLoggedEvents(
        prior: prior,
        loggedTimes: const [],
      );

      // Absence of data must never read as evidence of a quiet day.
      expect(calibrated.confidence, prior.confidence);
      expect(calibrated.basis, prior.basis);
      expect(calibrated.slotForHour(20).weight, prior.slotForHour(20).weight);
    });

    test('a few entries nudge the prior without overturning it', () {
      final prior = structuralPrior();

      final calibrated = engine.calibrateWithLoggedEvents(
        prior: prior,
        loggedTimes: loggedAt(21, 5),
      );

      // Five entries is one evening, not a pattern — the hour rises, but not
      // to the point of redrawing the day.
      expect(
        calibrated.slotForHour(21).weight,
        greaterThan(prior.slotForHour(21).weight),
      );
      expect(calibrated.topHours.first, isNot(21));
    });

    test('sustained logging takes over the shape of the day', () {
      final prior = structuralPrior();

      final calibrated = engine.calibrateWithLoggedEvents(
        prior: prior,
        loggedTimes: loggedAt(21, 200),
      );

      expect(calibrated.topHours.first, 21);
      expect(calibrated.confidence, greaterThan(prior.confidence));
    });

    test('weights still describe a distribution', () {
      final calibrated = engine.calibrateWithLoggedEvents(
        prior: structuralPrior(),
        loggedTimes: [...loggedAt(8, 30), ...loggedAt(21, 60)],
      );

      final total = calibrated.hourly
          .map((slot) => slot.weight)
          .reduce((a, b) => a + b);
      expect(total, closeTo(1.0, 0.001));
      expect(calibrated.hourly, hasLength(24));
    });

    test('confidence stays short of certainty however much is logged', () {
      final calibrated = engine.calibrateWithLoggedEvents(
        prior: structuralPrior(),
        loggedTimes: loggedAt(21, 5000),
      );

      // This remains a heuristic about human behaviour; presenting it as
      // near-certain would be its own kind of lie.
      expect(
        calibrated.confidence,
        lessThanOrEqualTo(SmokingTimePredictionEngine.maxCalibratedConfidence),
      );
    });
  });
}
