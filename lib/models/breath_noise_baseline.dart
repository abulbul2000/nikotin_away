/// Cihazın kendini kalibre etmesi için saklanan tek bir ortam gürültü
/// baseline ölçümü. StorageService, her testin başındaki ortam dinleme
/// adımından bir tane biriktirir; BreathNoiseCalibration bunların son
/// birkaç tanesinin medyanını cihaz referansı olarak kullanır — sabit bir
/// dB eşiği yerine, telefonlar arası mikrofon hassasiyeti farkını
/// kendiliğinden dengeler.
class BreathNoiseBaseline {
  final DateTime measuredAt;
  final double level;

  const BreathNoiseBaseline({required this.measuredAt, required this.level});

  Map<String, dynamic> toJson() {
    return {'measuredAt': measuredAt.toIso8601String(), 'level': level};
  }

  factory BreathNoiseBaseline.fromJson(Map<String, dynamic> json) {
    return BreathNoiseBaseline(
      measuredAt: DateTime.parse(json['measuredAt'] as String),
      level: (json['level'] as num).toDouble(),
    );
  }
}
