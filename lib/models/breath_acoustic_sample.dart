/// One energy reading derived from a chunk of live microphone audio during
/// a breath-test attempt. Deliberately carries only a single normalized
/// energy scalar and a timestamp — never the raw audio bytes themselves,
/// which are discarded the instant this sample is computed from them (see
/// BreathAudioService).
class BreathAcousticSample {
  final int millisecondsSinceStart;
  final double rmsEnergy;

  const BreathAcousticSample({
    required this.millisecondsSinceStart,
    required this.rmsEnergy,
  });
}
