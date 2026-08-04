/// Tek bir denemenin hemen ardından gösterilen, kullanıcıya-dönük kısa
/// geri bildirim. [BreathFeedbackEngine] tarafından üretilir.
///
/// Asla bir sağlık teşhisi ya da uyarısı değildir — yalnızca ölçüm
/// tekniğine dair (nasıl üflendiğine, telefonun nereye tutulduğuna dair)
/// bir öneridir. Ton her zaman cesaretlendirici, hiçbir zaman suçlayıcı.
enum BreathFeedbackTone { encouraging, neutral, positive }

class BreathAttemptFeedback {
  final String messageKey;
  final BreathFeedbackTone tone;

  const BreathAttemptFeedback({required this.messageKey, required this.tone});
}
