import '../models/breath_test_result.dart';
import '../services/storage_service.dart';

class BreathTestRepository {
  final StorageService _storageService;

  BreathTestRepository({StorageService? storageService})
    : _storageService = storageService ?? StorageService();

  Future<void> save(BreathTestResult result) {
    return _storageService.saveBreathTestResult(result);
  }

  Future<List<BreathTestResult>> loadRecent({int limit = 50}) {
    return _storageService.loadBreathTestResults(limit: limit);
  }
}
