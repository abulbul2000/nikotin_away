import '../engines/breath_acoustic_engine.dart';
import '../engines/breath_test_engine.dart';
import '../engines/wheeze_detection_engine.dart';
import '../models/breath_test_result.dart';
import '../models/survey_record.dart';
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
  }) : _storageService = storageService ?? StorageService(),
       _repository =
           repository ?? BreathTestRepository(storageService: storageService),
       _engine = engine ?? BreathTestEngine();

  /// [holdDuration] artık bir tutma süresi ölçümü değil — sadece
  /// SurveyRecord.exhaleTestSeconds'a (bkz. aşağı) taşınan, çağıranın en iyi
  /// üfleme denemesini raporladığı bir saniye değeri. BreathTestEngine artık
  /// hold'u hiç ölçmediği için bu, [BreathTestEngine.buildResult]'a
  /// geçirilmiyor — isimlendirme uyuşmazlığı bilinen bir sorun, FAZ 6'da ele
  /// alınacak.
  Future<ProcessedBreathTest> processBreathTest({
    required String name,
    required String packsPerDay,
    required double holdDuration,
    required double blowDuration,
    required double blowStability,
    required double blowIntensity,
    SpirometryEstimate? spirometry,
    WheezeAnalysis? wheeze,
    DateTime? completedAt,
    String title = 'Nefes Testi',
  }) async {
    final now = completedAt ?? DateTime.now();
    final result = _engine.buildResult(
      id: 'breath_${now.microsecondsSinceEpoch}',
      createdAt: now,
      blowDuration: blowDuration,
      blowIntensity: blowIntensity,
      blowStability: blowStability,
      spirometry: spirometry,
      wheeze: wheeze,
    );

    // Persist the raw breath result FIRST, then derive the risk score from a
    // single fresh dashboard computation (StorageService.loadBehaviorDashboard,
    // which itself calls BreathTestEngine.calculateFinalRisk). This is the
    // exact same formula/inputs the home dashboard uses, so the risk score
    // shown immediately after a test can never disagree with the score shown
    // later on the dashboard for the same data — previously this method kept
    // a second, independent copy of that blend (including its own duplicate
    // task-performance-risk calculation), which could diverge because
    // `dashboard.riskScore` already includes prior breath history, so
    // re-blending it here as "behaviorRisk" alongside a brand new breath
    // score double-counted past breath influence.
    await _repository.save(result);
    final dashboard = await _storageService.loadBehaviorDashboard();
    final finalRisk = dashboard.riskScore;
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

    await _storageService.saveSurveyRecord(surveyRecord);

    return ProcessedBreathTest(
      breathResult: result,
      surveyRecord: surveyRecord,
      finalRiskScore: finalRisk,
      finalRiskLevel: finalRiskLevel,
    );
  }
}
