/// A single "the user smoked" event, logged either in the moment (the
/// optional quick-log button) or recalled afterward (the daily bedtime
/// check-in). This is the ground-truth data source that
/// [SmokingTimePredictionEngine]'s structural guess is meant to eventually
/// be calibrated against.
class SmokingEvent {
  final String id;

  /// When the cigarette was smoked. For quick-logged events this is the
  /// exact moment logged; for recalled events it's the user's best-guess
  /// hour on the day being recalled.
  final DateTime timestamp;

  /// 'quick_log' (logged in the moment) or 'daily_recall' (entered during
  /// the bedtime check-in for a time earlier that day).
  final String source;

  /// True when [timestamp] is a recalled approximation rather than the
  /// precise logged moment.
  final bool approximate;

  /// Canonical reason the user smoked, if they answered the follow-up prompt.
  final String? trigger;

  /// Which of the user's [SignificantPlace]s this happened at, if any.
  ///
  /// An id, never coordinates. The app stores at most a handful of finalised
  /// place centroids and no location trail at all; writing a position onto
  /// every cigarette would assemble exactly the movement history that design
  /// sets out to avoid. "Which of your usual places" is the whole of what the
  /// risky-hour ranking needs.
  ///
  /// Null whenever location was unavailable — permission refused, no fix,
  /// feature switched off, or simply somewhere the user doesn't often go.
  /// Location never gates the record.
  final String? placeId;

  const SmokingEvent({
    required this.id,
    required this.timestamp,
    required this.source,
    required this.approximate,
    this.placeId,
    this.trigger,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'source': source,
      'approximate': approximate ? 1 : 0,
      'placeId': placeId,
      'trigger': trigger,
    };
  }

  factory SmokingEvent.fromJson(Map<String, dynamic> json) {
    return SmokingEvent(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      source: json['source'] as String? ?? 'daily_recall',
      approximate: ((json['approximate'] as num?)?.toInt() ?? 1) == 1,
      placeId: json['placeId'] as String?,
      trigger: json['trigger'] as String?,
    );
  }
}
