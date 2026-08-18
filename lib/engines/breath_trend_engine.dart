import '../core/app_texts.dart';
import '../models/breath_progress_record.dart';
import '../models/breath_progress_summary.dart';

/// Turns a raw history of [BreathProgressRecord]s into a
/// [BreathProgressSummary] for the progress/analysis page. Pure and DB-free
/// like the other engines (see StepTrendEngine) — all persistence happens
/// one layer up.
///
/// Gürültülü işaretli kayıtlar ([BreathProgressRecord.isNoisyEnvironment])
/// her istatistikten (pencere ortalamaları, en iyi skor, kayan ortalama,
/// hafta karşılaştırması) tamamen dışlanır — trend hesabını bozmasınlar
/// diye. Yalnızca grafiğin o günü "atlandı" olarak işaretlemesi için
/// kullanılırlar.
class BreathTrendEngine {
  // Tek yerde tanımlı skor bileşen ağırlıkları — kolay ayarlanabilsin diye.
  // Üfleme süresi en anlamlı sinyal olduğu için en yüksek payı alır.
  static const double blowDurationWeight = 0.50;
  static const double stabilityWeight = 0.30;
  static const double intensityWeight = 0.20;

  // Bundan az test varken trend/karşılaştırma gösterilmez — tek tük
  // testten çıkarılan bir eğilim kullanıcıyı yanlış yönlendirebilir.
  static const int minimumTestCountForTrend = 5;

  static const int _movingAverageWindowDays = 7;
  static const int _comparisonWindowDays = 7;

  static const double _significantImprovementThresholdPercent = 10;
  static const double _gradualImprovementThresholdPercent = 3;
  static const double _declineThresholdPercent = -3;

  /// 0-100 arası tek bir "Nefes Skoru". Süre/tutarlılık/güç bileşenlerinin
  /// ağırlıklı ortalaması — her bileşen kendi doğal ölçeğinden önce 0-1
  /// aralığına normalize edilir.
  ///
  /// [blowDurationSeconds] 10 saniyede tavan yapacak şekilde normalize
  /// edilir: gerçekçi bir zorlu üflemenin üst sınırı bu civarda, daha
  /// uzunu ekstra puan getirmez.
  double computeScore({
    required double blowDurationSeconds,
    required double blowStability,
    required double blowIntensity,
  }) {
    const durationCeilingSeconds = 10.0;
    final durationSignal = (blowDurationSeconds / durationCeilingSeconds).clamp(
      0.0,
      1.0,
    );
    final stabilitySignal = blowStability.clamp(0.0, 1.0);
    final intensitySignal = blowIntensity.clamp(0.0, 1.0);

    final score =
        (durationSignal * blowDurationWeight) +
        (stabilitySignal * stabilityWeight) +
        (intensitySignal * intensityWeight);
    return (score * 100).clamp(0, 100).toDouble();
  }

  /// 3 denemenin skorlarının ortancası — en iyi deneme şansa bağlı
  /// olabileceğinden, ortanca daha dürüst bir gösterge.
  double medianOfAttemptScores(List<double> attemptScores) {
    if (attemptScores.isEmpty) {
      return 0;
    }
    final sorted = [...attemptScores]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  BreathProgressSummary summarize(
    List<BreathProgressRecord> records, {
    required String languageCode,
  }) {
    if (records.isEmpty) {
      return BreathProgressSummary.empty();
    }

    final sorted = [...records]
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    // Legacy (schemaVersion 1) rows recorded blowDurationSeconds as
    // hold+rest time folded in (see BreathProgressRecord.currentSchemaVersion)
    // — excluded from trend/chart statistics the same way noisy rows are,
    // so old inflated durations can't make the trend look like a decline.
    final clean = sorted
        .where(
          (r) =>
              !r.isNoisyEnvironment &&
              r.schemaVersion >= BreathProgressRecord.currentSchemaVersion,
        )
        .toList();

    // "Last N days" means the real last N days, not the N days ending on
    // whenever this user happened to last test — anchoring to the last
    // record's own timestamp let a burst of tests from months ago still
    // read as "12 tests in the last 30 days" the next time this summary
    // was computed, however long the user had been away since.
    final now = DateTime.now();
    final last7 = _window(clean, days: 7, now: now);
    final last30 = _window(clean, days: 30, now: now);
    final last90 = _window(clean, days: 90, now: now);

    final chartPoints = _buildChartPoints(sorted, clean);

    final hasEnoughData = clean.length >= minimumTestCountForTrend;

    double? weekOverWeekChange;
    var direction = BreathProgressDirection.stable;
    var insight = '';

    if (hasEnoughData) {
      weekOverWeekChange = _firstWeekVsLastWeekChangePercent(clean);
      if (weekOverWeekChange != null) {
        direction = _resolveDirection(weekOverWeekChange);
        insight = _buildInsightMessage(
          direction,
          weekOverWeekChange,
          languageCode,
        );
      } else {
        insight = AppTexts.textForCode(
          languageCode,
          'breathInsightNotEnoughSpan',
        );
      }
    } else {
      insight = AppTexts.textForCode(
        languageCode,
        'breathInsightNotEnoughTests',
      );
    }

    final bestRecord = clean.isEmpty
        ? null
        : clean.reduce((a, b) => a.breathScore >= b.breathScore ? a : b);
    final bestDurationRecord = clean.isEmpty
        ? null
        : clean.reduce(
            (a, b) => a.blowDurationSeconds >= b.blowDurationSeconds ? a : b,
          );

    return BreathProgressSummary(
      totalTestCount: sorted.length,
      hasEnoughDataForTrend: hasEnoughData,
      last7Days: last7,
      last30Days: last30,
      last90Days: last90,
      chartPoints: chartPoints,
      scoreChangeFirstWeekVsLastWeekPercent: weekOverWeekChange,
      direction: direction,
      bestScore: bestRecord?.breathScore ?? 0,
      bestScoreDate: bestRecord?.completedAt,
      bestBlowDurationSeconds: bestDurationRecord?.blowDurationSeconds ?? 0,
      bestBlowDurationDate: bestDurationRecord?.completedAt,
      testsPerWeekLast30Days: last30.testCount / (30 / 7),
      insightMessage: insight,
    );
  }

  BreathProgressWindow _window(
    List<BreathProgressRecord> cleanRecordsAscending, {
    required int days,
    required DateTime now,
  }) {
    final cutoff = now.subtract(Duration(days: days));
    final inWindow = cleanRecordsAscending
        .where((r) => !r.completedAt.isBefore(cutoff))
        .toList();
    if (inWindow.isEmpty) {
      return BreathProgressWindow(
        windowDays: days,
        testCount: 0,
        averageScore: 0,
        averageBlowDurationSeconds: 0,
        averageStability: 0,
      );
    }
    return BreathProgressWindow(
      windowDays: days,
      testCount: inWindow.length,
      averageScore: _average(inWindow.map((r) => r.breathScore)),
      averageBlowDurationSeconds: _average(
        inWindow.map((r) => r.blowDurationSeconds),
      ),
      averageStability: _average(inWindow.map((r) => r.blowStability)),
    );
  }

  /// İlk [_comparisonWindowDays] takvim günündeki (gürültüsüz) kayıtların
  /// ortalama skoru ile son [_comparisonWindowDays] takvim günündeki
  /// kayıtların ortalama skoru arasındaki değişim yüzdesi. Tek ilk test ↔
  /// tek son test kıyaslaması değil, pencere ortalamaları kıyaslanır.
  ///
  /// İki pencere aynı kayıtları paylaşacak kadar (toplam aralık 2 haftadan
  /// az) çakışıyorsa null döner — o zaman anlamlı bir "önce/sonra"
  /// karşılaştırması yok demektir.
  double? _firstWeekVsLastWeekChangePercent(
    List<BreathProgressRecord> cleanRecordsAscending,
  ) {
    final first = cleanRecordsAscending.first.completedAt;
    final last = cleanRecordsAscending.last.completedAt;
    if (last.difference(first).inDays < _comparisonWindowDays * 2) {
      return null;
    }

    final firstWeekEnd = first.add(Duration(days: _comparisonWindowDays));
    final lastWeekStart = last.subtract(Duration(days: _comparisonWindowDays));

    final firstWeekRecords = cleanRecordsAscending
        .where((r) => r.completedAt.isBefore(firstWeekEnd))
        .toList();
    final lastWeekRecords = cleanRecordsAscending
        .where((r) => !r.completedAt.isBefore(lastWeekStart))
        .toList();

    if (firstWeekRecords.isEmpty || lastWeekRecords.isEmpty) {
      return null;
    }

    final firstAvg = _average(firstWeekRecords.map((r) => r.breathScore));
    final lastAvg = _average(lastWeekRecords.map((r) => r.breathScore));
    if (firstAvg <= 0) {
      return null;
    }
    return ((lastAvg - firstAvg) / firstAvg) * 100;
  }

  BreathProgressDirection _resolveDirection(double changePercent) {
    if (changePercent > _significantImprovementThresholdPercent) {
      return BreathProgressDirection.significantImprovement;
    }
    if (changePercent > _gradualImprovementThresholdPercent) {
      return BreathProgressDirection.gradualImprovement;
    }
    if (changePercent >= _declineThresholdPercent) {
      return BreathProgressDirection.stable;
    }
    return BreathProgressDirection.decline;
  }

  String _buildInsightMessage(
    BreathProgressDirection direction,
    double changePercent,
    String languageCode,
  ) {
    final rounded = changePercent.abs().round();
    switch (direction) {
      case BreathProgressDirection.significantImprovement:
        return AppTexts.textForCode(
          languageCode,
          'breathInsightSignificantImprovement',
        ).replaceAll('{percent}', '$rounded');
      case BreathProgressDirection.gradualImprovement:
        return AppTexts.textForCode(
          languageCode,
          'breathInsightGradualImprovement',
        ).replaceAll('{percent}', '$rounded');
      case BreathProgressDirection.stable:
        return AppTexts.textForCode(languageCode, 'breathInsightStable');
      case BreathProgressDirection.decline:
        // Kasıtlı olarak sakin bir ton — düşüş hastalık, uyku eksikliği
        // veya stres gibi çok şeyden kaynaklanabilir. Alarm verme,
        // suçlama.
        return AppTexts.textForCode(languageCode, 'breathInsightDecline');
    }
  }

  List<BreathProgressChartPoint> _buildChartPoints(
    List<BreathProgressRecord> allRecordsAscending,
    List<BreathProgressRecord> cleanRecordsAscending,
  ) {
    if (allRecordsAscending.isEmpty) {
      return const [];
    }

    final startDay = _dateOnly(allRecordsAscending.first.completedAt);
    final endDay = _dateOnly(allRecordsAscending.last.completedAt);

    final cleanByDay = <DateTime, List<double>>{};
    for (final record in cleanRecordsAscending) {
      final day = _dateOnly(record.completedAt);
      (cleanByDay[day] ??= []).add(record.breathScore);
    }
    final noisyDays = <DateTime>{
      for (final record in allRecordsAscending)
        if (record.isNoisyEnvironment) _dateOnly(record.completedAt),
    };

    final dailyAverages = <DateTime, double>{
      for (final entry in cleanByDay.entries) entry.key: _average(entry.value),
    };

    final points = <BreathProgressChartPoint>[];
    var cursor = startDay;
    final orderedDays = <DateTime>[];
    while (!cursor.isAfter(endDay)) {
      orderedDays.add(cursor);
      // Calendar-day increment, not a fixed 24h Duration — on a DST
      // transition day, adding Duration(days: 1) to a local-time midnight
      // lands on 23:00 or 01:00 instead of the next midnight, which then
      // never matches any _dateOnly() key and drops that day (and every
      // day after it, since the drift compounds) from the chart.
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }

    for (var i = 0; i < orderedDays.length; i++) {
      final day = orderedDays[i];
      final windowStart = i - _movingAverageWindowDays + 1;
      double? movingAverage;
      if (windowStart >= 0) {
        final windowDays = orderedDays.sublist(windowStart, i + 1);
        final windowScores = windowDays
            .map((d) => dailyAverages[d])
            .whereType<double>()
            .toList();
        if (windowScores.isNotEmpty) {
          movingAverage = _average(windowScores);
        }
      }

      points.add(
        BreathProgressChartPoint(
          date: day,
          rawScore: dailyAverages[day],
          movingAverageScore: movingAverage,
          hasSkippedNoisyTest: noisyDays.contains(day),
        ),
      );
    }

    return points;
  }

  double _average(Iterable<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    return values.reduce((a, b) => a + b) / values.length;
  }

  DateTime _dateOnly(DateTime dateTime) {
    final local = dateTime.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
