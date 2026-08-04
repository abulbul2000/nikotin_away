/// İki kademeli ortam gürültü seviyesi. Hiçbir kademe testi engellemez —
/// yalnızca bir uyarı gösterip kaydı işaretlemek için kullanılır.
enum NoiseLevel {
  /// Referansa yakın, sorun yok.
  quiet,

  /// Referansın ~2 katı civarı — "gürültülü olabilir" uyarısı gösterilir,
  /// kullanıcı Devam Et / Tekrar Dene seçer.
  warning,

  /// Referansın ~4 katı civarı — daha net bir uyarı, kayıt isNoisy=true
  /// işaretlenir.
  loud,
}

/// Test başlamadan önceki kısa ortam dinleme adımının ya da test sırasında
/// üfleme öncesi sessiz pencerenin sonucu.
///
/// Sabit bir dB eşiği kullanmaz — telefonlar arası mikrofon hassasiyeti çok
/// değiştiği için göreli çalışır: seviye, cihazın kendi geçmiş baseline
/// ölçümlerinin medyanına (bkz. BreathNoiseCalibration) göre değerlendirilir.
/// Bloklayıcı değildir: [level] ne olursa olsun kullanıcı teste devam
/// edebilir; tek etkisi bir uyarı göstermek ve o kaydı
/// [BreathProgressRecord.isNoisyEnvironment] ile işaretlemektir.
class NoiseCheckResult {
  /// Dinleme penceresinde ölçülen ortalama ses enerjisi seviyesi (ham,
  /// BreathAcousticEngine ile aynı birim/ölçek).
  final double measuredLevel;

  /// Aynı pencere içindeki örnekler arası oynaklık (standart sapma veya
  /// IQR). Sabit bir uğultudan çok, konuşma/TV gibi ani sıçramaları
  /// yakalamak için seviyeden ayrı değerlendirilir — üfleme onset tespiti
  /// bu tür ani sıçramalara takılır.
  final double volatility;

  /// Bu ölçümün karşılaştırıldığı cihaz referans seviyesi (son 10 baseline
  /// ölçümünün medyanı, yeterli geçmiş yoksa makul bir varsayılan).
  final double referenceLevel;

  final NoiseLevel level;

  const NoiseCheckResult({
    required this.measuredLevel,
    required this.volatility,
    required this.referenceLevel,
    required this.level,
  });

  bool get isNoisy => level != NoiseLevel.quiet;

  /// Kayda "gürültülü ortamda alındı" işareti basılsın mı. Yalnızca en üst
  /// kademe (loud) bunu tetikler — warning kademesi sadece bir öneri
  /// gösterir, kaydı işaretlemez.
  bool get shouldMarkRecordAsNoisy => level == NoiseLevel.loud;
}
