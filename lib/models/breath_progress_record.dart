/// Nefes testi ilerleme sayfasında ve trend hesaplamalarında kullanılan,
/// kullanıcıya-dönük tek bir test kaydı.
///
/// [BreathTestResult]'tan (ham motor çıktısı: risk katkıları, iç
/// spirometri-benzeri alanlar) kasıtlı olarak ayrı tutulur — bu model
/// sadece "Nefes Skoru" gibi ürünün kendi ölçeğindeki, tıbbi olmayan
/// değerleri taşır. Böylece analiz/trend katmanı, risk motorunun iç
/// temsiline bağımlı olmadan bağımsız gelişebilir.
class BreathProgressRecord {
  final String id;
  final DateTime completedAt;

  /// 0-100 arası, uygulama içi kendi ölçeğimiz. Tıbbi bir referansla
  /// karşılaştırılamaz; yalnızca kullanıcının kendi geçmişiyle
  /// kıyaslanır.
  final double breathScore;

  /// Saniye cinsinden üfleme süresi.
  final double blowDurationSeconds;

  /// 0-1 arası, üflemenin ne kadar sabit bir güçle yapıldığı.
  final double blowStability;

  /// 0-1 arası, üflemenin göreli gücü.
  final double blowIntensity;

  /// Test sırasında ortam gürültüsü eşiğin üzerindeyse true. Trend
  /// hesaplarında bu kayıtların ağırlığı düşürülür veya işaretli
  /// gösterilir — bkz. BreathTrendEngine.
  final bool isNoisyEnvironment;

  const BreathProgressRecord({
    required this.id,
    required this.completedAt,
    required this.breathScore,
    required this.blowDurationSeconds,
    required this.blowStability,
    required this.blowIntensity,
    this.isNoisyEnvironment = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'completedAt': completedAt.toIso8601String(),
      'breathScore': breathScore,
      'blowDurationSeconds': blowDurationSeconds,
      'blowStability': blowStability,
      'blowIntensity': blowIntensity,
      'isNoisyEnvironment': isNoisyEnvironment,
    };
  }

  factory BreathProgressRecord.fromJson(Map<String, dynamic> json) {
    return BreathProgressRecord(
      id: json['id'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String),
      breathScore: (json['breathScore'] as num).toDouble(),
      blowDurationSeconds: (json['blowDurationSeconds'] as num).toDouble(),
      blowStability: (json['blowStability'] as num).toDouble(),
      blowIntensity: (json['blowIntensity'] as num).toDouble(),
      isNoisyEnvironment: json['isNoisyEnvironment'] as bool? ?? false,
    );
  }
}
