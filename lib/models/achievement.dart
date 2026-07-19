class Achievement {
  final String id;
  final String titleKey;
  final String descriptionKey;
  final String icon; // emoji or asset key
  final int thresholdDays; // smoke-free days required to unlock
  final bool unlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
    required this.thresholdDays,
    this.unlocked = false,
    this.unlockedAt,
  });

  Achievement copyWith({bool? unlocked, DateTime? unlockedAt}) {
    return Achievement(
      id: id,
      titleKey: titleKey,
      descriptionKey: descriptionKey,
      icon: icon,
      thresholdDays: thresholdDays,
      unlocked: unlocked ?? this.unlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'unlocked': unlocked,
        'unlockedAt': unlockedAt?.toIso8601String(),
      };

  static Achievement fromJsonState(Achievement base, Map<String, dynamic> json) {
    return base.copyWith(
      unlocked: json['unlocked'] as bool? ?? false,
      unlockedAt:
          json['unlockedAt'] != null ? DateTime.parse(json['unlockedAt'] as String) : null,
    );
  }

  /// Master list of all badges the app can award, ordered by difficulty.
  static const List<Achievement> catalog = [
    Achievement(
      id: 'day_1',
      titleKey: 'achievementFirstDayTitle',
      descriptionKey: 'achievementFirstDayDesc',
      icon: '🌱',
      thresholdDays: 1,
    ),
    Achievement(
      id: 'day_3',
      titleKey: 'achievementThreeDaysTitle',
      descriptionKey: 'achievementThreeDaysDesc',
      icon: '🔥',
      thresholdDays: 3,
    ),
    Achievement(
      id: 'day_7',
      titleKey: 'achievementOneWeekTitle',
      descriptionKey: 'achievementOneWeekDesc',
      icon: '⭐',
      thresholdDays: 7,
    ),
    Achievement(
      id: 'day_14',
      titleKey: 'achievementTwoWeeksTitle',
      descriptionKey: 'achievementTwoWeeksDesc',
      icon: '💪',
      thresholdDays: 14,
    ),
    Achievement(
      id: 'day_30',
      titleKey: 'achievementOneMonthTitle',
      descriptionKey: 'achievementOneMonthDesc',
      icon: '🏆',
      thresholdDays: 30,
    ),
    Achievement(
      id: 'day_90',
      titleKey: 'achievementThreeMonthsTitle',
      descriptionKey: 'achievementThreeMonthsDesc',
      icon: '🥇',
      thresholdDays: 90,
    ),
    Achievement(
      id: 'day_180',
      titleKey: 'achievementSixMonthsTitle',
      descriptionKey: 'achievementSixMonthsDesc',
      icon: '👑',
      thresholdDays: 180,
    ),
    Achievement(
      id: 'day_365',
      titleKey: 'achievementOneYearTitle',
      descriptionKey: 'achievementOneYearDesc',
      icon: '💎',
      thresholdDays: 365,
    ),
  ];
}
