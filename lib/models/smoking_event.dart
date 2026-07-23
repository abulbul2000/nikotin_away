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

  const SmokingEvent({
    required this.id,
    required this.timestamp,
    required this.source,
    required this.approximate,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'source': source,
      'approximate': approximate ? 1 : 0,
    };
  }

  factory SmokingEvent.fromJson(Map<String, dynamic> json) {
    return SmokingEvent(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      source: json['source'] as String? ?? 'daily_recall',
      approximate: ((json['approximate'] as num?)?.toInt() ?? 1) == 1,
    );
  }
}
