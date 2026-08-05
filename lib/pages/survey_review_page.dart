import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../models/survey_record.dart';
import '../services/behavior_engine.dart';
import 'home_page.dart';
import 'survey_history_page.dart';

class SurveyReviewPage extends StatelessWidget {
  final SurveyRecord currentRecord;
  final SurveyRecord? previousRecord;
  final BehaviorEngine _behaviorEngine = BehaviorEngine();

  SurveyReviewPage({
    super.key,
    required this.currentRecord,
    required this.previousRecord,
  });

  @override
  Widget build(BuildContext context) {
    final packLevelDelta = previousRecord == null
      ? null
      : SurveyRecord.packLevel(currentRecord.packsPerDay) -
        SurveyRecord.packLevel(previousRecord!.packsPerDay);
    final exhaleDelta = previousRecord == null
        ? null
        : currentRecord.exhaleTestSeconds - previousRecord!.exhaleTestSeconds;
    final inhaleDelta = previousRecord == null
        ? null
        : currentRecord.inhaleTestSeconds - previousRecord!.inhaleTestSeconds;
    final riskDelta = previousRecord == null
        ? null
        : currentRecord.riskScore - previousRecord!.riskScore;
    final consecutiveSmokingCurrent = _buildConsecutiveSmokingLabel(currentRecord);
    final consecutiveSmokingPrevious = previousRecord == null
      ? null
      : _buildConsecutiveSmokingLabel(previousRecord!);
    final consecutiveSmokingTrend = previousRecord == null
      ? context.t('firstEvaluation')
      : _behaviorEngine.evaluateConsecutiveSmokingTrend(
        previousHabit: previousRecord!.consecutiveSmokingHabit,
        previousCount: previousRecord!.consecutiveSmokingCount,
        currentHabit: currentRecord.consecutiveSmokingHabit,
        currentCount: currentRecord.consecutiveSmokingCount,
        );

    final hasImprovement = (packLevelDelta ?? 0) < 0 ||
        (exhaleDelta ?? 0) < 0 ||
        (inhaleDelta ?? 0) < 0 ||
        (riskDelta ?? 0) < 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('evaluation')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasImprovement ? context.t('progressPositive') : context.t('progressNegative'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              hasImprovement
                  ? context.t('progressPositiveDetail')
                  : context.t('progressNegativeDetail'),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            _buildPackMetric(),
            _buildMetric(context.t('exhaleDelta'), exhaleDelta, context.t('secShort'), context),
            _buildMetric(context.t('inhaleDelta'), inhaleDelta, context.t('secShort'), context),
            _buildMetric(context.t('riskDelta'), riskDelta, context.t('pointShort'), context),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: Text(context.t('chainSmoking')),
                subtitle: Text(
                  previousRecord == null
                      ? context.t('firstEvaluation')
                      : '${consecutiveSmokingPrevious ?? context.t('noRecordYet')} -> $consecutiveSmokingCurrent',
                ),
                trailing: Text(consecutiveSmokingTrend),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SurveyHistoryPage()),
                  );
                },
                child: Text(context.t('viewAllSurveys')),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HomePage(
                        name: currentRecord.name,
                        riskScore: currentRecord.riskScore,
                        riskLevel: currentRecord.riskLevel,
                      ),
                    ),
                    (route) => false,
                  );
                },
                child: Text(context.t('backToHome')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String title, int? delta, String unit, BuildContext context) {
    final display = delta == null ? context.t('firstEvaluation') : '${delta > 0 ? '+' : ''}$delta $unit';
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(display),
      ),
    );
  }

  Widget _buildPackMetric() {
    final change = previousRecord == null
        ? null
        : '${previousRecord!.packsPerDay} -> ${currentRecord.packsPerDay}';
    return Card(
      child: ListTile(
        title: Builder(
          builder: (context) => Text(context.t('packChangeDaily')),
        ),
        trailing: Builder(
          builder: (context) => Text(change ?? context.t('firstEvaluation')),
        ),
      ),
    );
  }

  String _buildConsecutiveSmokingLabel(SurveyRecord record) {
    return _behaviorEngine.summarizeConsecutiveSmoking(
      habit: record.consecutiveSmokingHabit,
      count: record.consecutiveSmokingCount,
    );
  }
}
