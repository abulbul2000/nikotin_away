import 'cough_test_record.dart';
import 'reduction_progress.dart';

/// Everything the pre-sleep routine's final step shows, gathered into one
/// package by `StorageService.buildDailyProgressReport`.
///
/// Deliberately not built from `ReportEngine` (see `reports_page.dart`) —
/// that machine produces weekly/monthly `PeriodReport`s with PDF export,
/// which is far more than a same-day summary screen needs.
class DailyProgressReport {
  const DailyProgressReport({
    required this.reductionProgress,
    required this.taskSuccessRateLast7Days,
    required this.currentBarrierMinutes,
    required this.lastBreathTestAt,
    required this.breathTrend,
    required this.todaySmokedCount,
    required this.latestCoughTest,
  });

  final ReductionProgress reductionProgress;
  final double taskSuccessRateLast7Days;
  final int currentBarrierMinutes;
  final DateTime? lastBreathTestAt;
  final String? breathTrend;
  final int todaySmokedCount;
  final CoughTestRecord? latestCoughTest;
}
