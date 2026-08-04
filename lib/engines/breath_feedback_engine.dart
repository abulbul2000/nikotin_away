import '../models/breath_attempt_feedback.dart';

/// Bir denemenin bitişinin hemen ardından gösterilecek kısa, tek satırlık
/// geri bildirimi üretir. Pure ve DB-free, diğer engine'ler gibi — hangi
/// çeviri anahtarının gösterileceğine karar verir, metnin kendisini ya da
/// UI'ı hiç bilmez.
///
/// Öncelik sırası: önce "önceki denemenden daha güçlüydü" gibi olumlu bir
/// karşılaştırma varsa o gösterilir (kullanıcıyı asıl motive eden budur);
/// yoksa en belirgin teknik sorun gösterilir — süre en ağırlıklı skor
/// bileşeni olduğu için önce o kontrol edilir, sonra tutarlılık, sonra
/// ses şiddeti. Aynı anda birden fazla sorun olabilir ama tek seferde tek
/// bir kısa cümle gösterilir — bir liste kullanıcıyı boğar.
class BreathFeedbackEngine {
  // Bu değerlerin altı "kısa üfleme" sayılır — BreathTrendEngine.computeScore
  // ile aynı 15sn'lik tavanın kabaca üçte biri, gerçekten kısa kalmış bir
  // üflemeyi yakalamak için.
  static const double shortBlowDurationThresholdSeconds = 5;

  // 0-1 ölçeğinde bu değerin altı "düşük tutarlılık" sayılır.
  static const double lowStabilityThreshold = 0.5;

  // 0-1 ölçeğinde bu değerin altı "zayıf ses" sayılır.
  static const double weakIntensityThreshold = 0.3;

  // "Öncekinden iyi" sayılması için skorun en az bu kadar artmış olması
  // gerekir — çok küçük dalgalanmalar (ör. +1 puan) bir başarı olarak
  // sunulmamalı.
  static const double improvementScoreThreshold = 5;

  BreathAttemptFeedback buildFeedback({
    required double blowDurationSeconds,
    required double blowStability,
    required double blowIntensity,
    required double currentScore,
    double? previousScore,
  }) {
    if (previousScore != null &&
        currentScore - previousScore >= improvementScoreThreshold) {
      return const BreathAttemptFeedback(
        messageKey: 'breathFeedbackBetterThanBefore',
        tone: BreathFeedbackTone.positive,
      );
    }

    if (blowDurationSeconds < shortBlowDurationThresholdSeconds) {
      return const BreathAttemptFeedback(
        messageKey: 'breathFeedbackTooShort',
        tone: BreathFeedbackTone.encouraging,
      );
    }

    if (blowStability < lowStabilityThreshold) {
      return const BreathAttemptFeedback(
        messageKey: 'breathFeedbackLowStability',
        tone: BreathFeedbackTone.encouraging,
      );
    }

    if (blowIntensity < weakIntensityThreshold) {
      return const BreathAttemptFeedback(
        messageKey: 'breathFeedbackWeakSignal',
        tone: BreathFeedbackTone.encouraging,
      );
    }

    return const BreathAttemptFeedback(
      messageKey: 'breathFeedbackGoodAttempt',
      tone: BreathFeedbackTone.neutral,
    );
  }
}
