/// Belirli bir pencere (ör. son 30 gün) için hesaplanmış özet istatistik.
/// [BreathTrendEngine] tarafından üretilir, analiz sayfasında ve ana
/// ekrandaki kısa özetlerde gösterilir. Gürültülü işaretli kayıtlar bu
/// pencerelerin hiçbirine dahil edilmez.
class BreathProgressWindow {
  final int windowDays;
  final int testCount;
  final double averageScore;
  final double averageBlowDurationSeconds;
  final double averageStability;

  const BreathProgressWindow({
    required this.windowDays,
    required this.testCount,
    required this.averageScore,
    required this.averageBlowDurationSeconds,
    required this.averageStability,
  });
}

/// Grafikte gösterilecek tek bir gün için hem ham (o günün gürültüsüz
/// testlerinin ortalaması) hem de 7 günlük kayan ortalama değeri.
///
/// Grafik ham noktaları soluk renkte arka planda, kayan ortalamayı ise ön
/// planda belirgin bir çizgi olarak çizer — tek tek testler gün gün çok
/// dalgalı olabildiği için asıl anlatılan eğilim kayan ortalamadır.
class BreathProgressChartPoint {
  final DateTime date;

  /// O güne ait (gürültüsüz) testlerin ortalama skoru. Null: o gün hiç
  /// (gürültüsüz) test yapılmamışsa.
  final double? rawScore;

  /// O günü bitiren 7 günlük kayan ortalama. Null: pencerenin başına yakın,
  /// henüz 7 günlük veri birikmemişse.
  final double? movingAverageScore;

  /// O gün en az bir test gürültülü olarak işaretlendiği için hesaba
  /// katılmadıysa true — grafikte kullanıcıya "neden bu gün eksik/atlandı"
  /// bilgisini göstermek için.
  final bool hasSkippedNoisyTest;

  const BreathProgressChartPoint({
    required this.date,
    required this.rawScore,
    required this.movingAverageScore,
    required this.hasSkippedNoisyTest,
  });
}

/// Trend yorumunun yönü. [BreathTrendEngine] eşiklere göre üretir:
/// > +%10 belirginİyileşme, +%3..+%10 yavaşİlerleme, -%3..+%3 sabit,
/// < -%3 düşüş (sakin, suçlamayan bir ton ister — bkz. insightMessage).
enum BreathProgressDirection {
  significantImprovement,
  gradualImprovement,
  stable,
  decline,
}

/// Tüm kayıt geçmişinden türetilen ilerleme özeti. Bu model UI'a doğrudan
/// bağlanacak şekilde tasarlanmıştır — hesaplama mantığının tamamı
/// BreathTrendEngine içinde kalır, bu sınıf sadece sonucu taşır.
class BreathProgressSummary {
  final int totalTestCount;

  /// Trend/karşılaştırma göstermek için yeterli veri var mı
  /// (BreathTrendEngine.minimumTestCountForTrend, en az 5-6 test).
  /// false ise UI "İlerlemeni görmek için birkaç test daha yap" mesajını
  /// gösterir; diğer tüm alanlar bu durumda da doldurulur ama boş/sıfır
  /// olabilir.
  final bool hasEnoughDataForTrend;

  final BreathProgressWindow last7Days;
  final BreathProgressWindow last30Days;
  final BreathProgressWindow last90Days;

  /// Grafik için: her gün bir nokta, tarihe göre sıralı.
  final List<BreathProgressChartPoint> chartPoints;

  /// İlk 7 günün ortalama skoru ile son 7 günün ortalama skoru arasındaki
  /// değişim yüzdesi. Tek ilk test ↔ tek son test kıyaslaması değildir.
  /// Null: [hasEnoughDataForTrend] false ise veya iki pencere de
  /// çakışıyorsa (toplam süre 14 günden/yeterli test sayısından az).
  final double? scoreChangeFirstWeekVsLastWeekPercent;

  final BreathProgressDirection direction;

  final double bestScore;
  final DateTime? bestScoreDate;

  final double bestBlowDurationSeconds;
  final DateTime? bestBlowDurationDate;

  /// Son 30 günde haftada kaç kez test yapıldığı (test düzenliliği).
  final double testsPerWeekLast30Days;

  /// Tek cümlelik, kullanıcıya-dönük yorum. [direction]'a göre üretilir;
  /// düşüş durumunda sakin ve suçlamayan bir tonda olacak şekilde
  /// (hastalık/uyku/stres gibi nedenler olabileceğini hatırlatan).
  /// Boş string: [hasEnoughDataForTrend] false ise.
  final String insightMessage;

  const BreathProgressSummary({
    required this.totalTestCount,
    required this.hasEnoughDataForTrend,
    required this.last7Days,
    required this.last30Days,
    required this.last90Days,
    required this.chartPoints,
    required this.scoreChangeFirstWeekVsLastWeekPercent,
    required this.direction,
    required this.bestScore,
    required this.bestScoreDate,
    required this.bestBlowDurationSeconds,
    required this.bestBlowDurationDate,
    required this.testsPerWeekLast30Days,
    required this.insightMessage,
  });

  factory BreathProgressSummary.empty() {
    const emptyWindow = BreathProgressWindow(
      windowDays: 0,
      testCount: 0,
      averageScore: 0,
      averageBlowDurationSeconds: 0,
      averageStability: 0,
    );
    return const BreathProgressSummary(
      totalTestCount: 0,
      hasEnoughDataForTrend: false,
      last7Days: emptyWindow,
      last30Days: emptyWindow,
      last90Days: emptyWindow,
      chartPoints: [],
      scoreChangeFirstWeekVsLastWeekPercent: null,
      direction: BreathProgressDirection.stable,
      bestScore: 0,
      bestScoreDate: null,
      bestBlowDurationSeconds: 0,
      bestBlowDurationDate: null,
      testsPerWeekLast30Days: 0,
      insightMessage: '',
    );
  }

  bool get hasData => totalTestCount > 0;
}
