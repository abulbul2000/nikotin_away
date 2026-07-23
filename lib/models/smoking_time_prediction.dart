/// One hour-of-day slot in a [SmokingTimePrediction].
class SmokingTimeSlot {
  /// 0-23, local time.
  final int hour;

  /// Relative likelihood for this hour; all 24 slots in a prediction sum to
  /// (approximately) 1.0.
  final double weight;

  /// This slot's share of the day's estimated total cigarette count.
  final int estimatedCigarettes;

  const SmokingTimeSlot({
    required this.hour,
    required this.weight,
    required this.estimatedCigarettes,
  });
}

/// A same-day distribution of "how likely is this hour to be a smoking
/// moment for this user", built from structural survey data (and, once
/// available, refined by real logged events). See
/// [SmokingTimePredictionEngine] for how it's computed.
class SmokingTimePrediction {
  /// Exactly 24 entries, index == hour.
  final List<SmokingTimeSlot> hourly;

  /// The most likely hours, descending by weight (excludes zero-weight
  /// hours, e.g. the sleep window).
  final List<int> topHours;

  /// 0.0-1.0 — how much this prediction leans on real observed data versus
  /// pure structural guesswork. Deliberately capped below 1.0: this is
  /// always a heuristic, never a certainty.
  final double confidence;

  /// 'structural' (survey schedule fields only) or 'structural+weekly'
  /// (also had weekly-survey trigger/meal data to work with).
  final String basis;

  /// Estimated average gap between cigarettes, in minutes, during the
  /// user's smokable hours (awake time minus sleep, further reduced by
  /// workplace hours where smoking isn't allowed). Null when there isn't
  /// enough data (sleep/wake time missing, or zero estimated cigarettes).
  final int? averageMinutesBetweenCigarettes;

  const SmokingTimePrediction({
    required this.hourly,
    required this.topHours,
    required this.confidence,
    required this.basis,
    this.averageMinutesBetweenCigarettes,
  });

  SmokingTimeSlot slotForHour(int hour) => hourly[hour.clamp(0, 23)];
}
