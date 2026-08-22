import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/services/sleep_routine_flow_engine.dart';

void main() {
  const engine = SleepRoutineFlowEngine();

  test(
    'without a discrepancy the flow is breath, cough, sleep time, wake time, report — 5 steps',
    () {
      final steps = engine.buildSteps(hasDiscrepancy: false);

      expect(steps, [
        SleepRoutineStep.breathTest,
        SleepRoutineStep.coughTest,
        SleepRoutineStep.tonightSleepTime,
        SleepRoutineStep.nextDayWakeTime,
        SleepRoutineStep.dailyReport,
      ]);
    },
  );

  test('with a discrepancy the flow still uses the current five steps', () {
    final steps = engine.buildSteps(hasDiscrepancy: true);

    expect(steps, [
      SleepRoutineStep.breathTest,
      SleepRoutineStep.coughTest,
      SleepRoutineStep.nextDayWakeTime,
      SleepRoutineStep.dailyReport,
    ]);
  });

  test('the report is always the last step, discrepancy or not', () {
    expect(
      engine.buildSteps(hasDiscrepancy: false).last,
      SleepRoutineStep.dailyReport,
    );
    expect(
      engine.buildSteps(hasDiscrepancy: true).last,
      SleepRoutineStep.dailyReport,
    );
  });

  test('breath test always comes before cough test', () {
    for (final hasDiscrepancy in [true, false]) {
      final steps = engine.buildSteps(hasDiscrepancy: hasDiscrepancy);
      expect(
        steps.indexOf(SleepRoutineStep.breathTest),
        lessThan(steps.indexOf(SleepRoutineStep.coughTest)),
      );
    }
  });
}
