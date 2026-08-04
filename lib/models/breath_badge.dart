/// What a breath-test badge is measured against. Kept as its own catalog
/// (see [BreathBadge.catalog]) rather than folded into [AchievementKind] in
/// achievement.dart — that catalog tracks smoking-reduction figures, this
/// one tracks breath-test engagement/performance, and the two shouldn't be
/// mixed under one threshold system.
enum BreathBadgeKind {
  /// Completed the very first breath test ever.
  firstTest,

  /// Consecutive calendar days with at least one (non-noisy) breath test.
  dailyStreak,

  /// Cumulative number of breath tests completed.
  totalTests,

  /// A new personal-best [BreathProgressRecord.breathScore]. Threshold is
  /// always 1 — this badge unlocks the first time *any* record beats the
  /// previous best, not at a fixed score value (see
  /// BreathBadgeEngine.evaluate).
  personalRecord,
}

class BreathBadge {
  final String id;
  final String titleKey;
  final String descriptionKey;
  final String icon;
  final BreathBadgeKind kind;
  final int threshold;

  final bool unlocked;
  final DateTime? unlockedAt;

  const BreathBadge({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
    required this.kind,
    required this.threshold,
    this.unlocked = false,
    this.unlockedAt,
  });

  BreathBadge copyWith({bool? unlocked, DateTime? unlockedAt}) {
    return BreathBadge(
      id: id,
      titleKey: titleKey,
      descriptionKey: descriptionKey,
      icon: icon,
      kind: kind,
      threshold: threshold,
      unlocked: unlocked ?? this.unlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'unlocked': unlocked,
    'unlockedAt': unlockedAt?.toIso8601String(),
  };

  static BreathBadge fromJsonState(BreathBadge base, Map<String, dynamic> json) {
    return base.copyWith(
      unlocked: json['unlocked'] as bool? ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'] as String)
          : null,
    );
  }

  /// Every breath-test badge the app can award.
  static const List<BreathBadge> catalog = [
    BreathBadge(
      id: 'breath_first_test',
      titleKey: 'breathBadgeFirstTestTitle',
      descriptionKey: 'breathBadgeFirstTestDesc',
      icon: '🎈',
      kind: BreathBadgeKind.firstTest,
      threshold: 1,
    ),
    BreathBadge(
      id: 'breath_streak_7',
      titleKey: 'breathBadgeStreak7Title',
      descriptionKey: 'breathBadgeStreak7Desc',
      icon: '🔥',
      kind: BreathBadgeKind.dailyStreak,
      threshold: 7,
    ),
    BreathBadge(
      id: 'breath_total_30',
      titleKey: 'breathBadgeTotal30Title',
      descriptionKey: 'breathBadgeTotal30Desc',
      icon: '🫁',
      kind: BreathBadgeKind.totalTests,
      threshold: 30,
    ),
    BreathBadge(
      id: 'breath_personal_record',
      titleKey: 'breathBadgePersonalRecordTitle',
      descriptionKey: 'breathBadgePersonalRecordDesc',
      icon: '🏅',
      kind: BreathBadgeKind.personalRecord,
      threshold: 1,
    ),
  ];
}
