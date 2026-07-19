import '../engines/breath_test_engine.dart';
import '../models/breath_test_result.dart';
import '../models/survey_record.dart';
import '../models/task_history.dart';
import '../repositories/breath_test_repository.dart';
import 'storage_service.dart';

class ProcessedBreathTest {
  final BreathTestResult breathResult;
  final SurveyRecord surveyRecord;
  final int finalRiskScore;
  final String finalRiskLevel;

  const ProcessedBreathTest({
    required this.breathResult,
    required this.surveyRecord,
    required this.finalRiskScore,
    required this.finalRiskLevel,
  });
}

class BreathTestService {
  final StorageService _storageService;
  final BreathTestRepository _repository;
  final BreathTestEngine _engine;

  BreathTestService({
    StorageService? storageService,
    BreathTestRepository? repository,
    BreathTestEngine? engine,
  })  : _storageService = storageService ?? StorageService(),
        _repository = repository ?? BreathTestRepository(storageService: storageService),
        _engine = engine ?? BreathTestEngine();

  Future<ProcessedBreathTest> processBreathTest({
    required String name,
    required String packsPerDay,
    required double holdDuration,
    required double blowDuration,
    required double blowStability,
    required double blowIntensity,
    DateTime? completedAt,
    String title = 'Nefes Testi',
  }) async {
    final now = completedAt ?? DateTime.now();
    final result = _engine.buildResult(
      id: 'breath_${now.microsecondsSinceEpoch}',
      createdAt: now,
      holdDuration: holdDuration,
      blowDuration: blowDuration,
      blowIntensity: blowIntensity,
      blowStability: blowStability,
    );

    final dashboard = await _storageService.loadBehaviorDashboard();
    final surveyRisk = dashboard.weeklySurveyRiskScore.toDouble();
    final behaviorRisk = dashboard.riskScore.toDouble();
    final taskPerformanceRisk = await _estimateTaskPerformanceRisk();

    final historical = await _repository.loadRecent(limit: 50);
    final trend = _engine.analyzeTrend([...historical, result]);

    final finalRisk = _engine.calculateFinalRisk(
      surveyRisk: surveyRisk,
      behaviorRisk: behaviorRisk,
      taskPerformanceRisk: taskPerformanceRisk,
      breathScore: result.breathScore,
      trendAdjustment: trend.riskAdjustment,
    );
    final finalRiskLevel = _engine.resolveRiskLevel(finalRisk);

    final surveyRecord = SurveyRecord(
      id: 'survey_${now.microsecondsSinceEpoch}',
      completedAt: now,
      type: 'breath_test',
      title: title,
      name: name,
      packsPerDay: packsPerDay,
      exhaleTestSeconds: holdDuration.round(),
      inhaleTestSeconds: blowDuration.round(),
      riskScore: finalRisk,
      riskLevel: finalRiskLevel,
    );

    await _repository.save(result);
    await _storageService.saveSurveyRecord(surveyRecord);

    return ProcessedBreathTest(
      breathResult: result,
      surveyRecord: surveyRecord,
      finalRiskScore: finalRisk,
      finalRiskLevel: finalRiskLevel,
    );
  }

  Future<double> _estimateTaskPerformanceRisk() async {
    final tasks = await _storageService.loadTaskHistory();
    return _estimateTaskPerformanceRiskFromTasks(tasks).toDouble();
  }

  int _estimateTaskPerformanceRiskFromTasks(List<TaskHistory> tasks) {
    if (tasks.isEmpty) {
      return 55;
    }

    final sorted = [...tasks]..sort((a, b) => a.date.compareTo(b.date));
    final recent = sorted.length > 14 ? sorted.sublist(sorted.length - 14) : sorted;
    final successCount = recent.where((item) => item.completed).length;
    final successRate = successCount / recent.length;
    var risk = ((1 - successRate) * 100).round();

    final streakWindow = recent.length > 5 ? recent.sublist(recent.length - 5) : recent;
    if (streakWindow.every((item) => item.completed)) {
      risk -= 4;
    } else if (streakWindow.every((item) => !item.completed)) {
      risk += 6;
    }

    return risk.clamp(0, 100);
  }
}
