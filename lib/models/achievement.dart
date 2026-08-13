/// What a badge is measured against.
///
/// The catalog used to be eight thresholds on one number: days since the
/// quit date. That number never checked whether the user had smoked, and it
/// measured abstinence in an app whose whole method is cutting down. Each
/// badge now names which reduction figure it watches.
enum AchievementKind {
  /// Consecutive days at or under the daily target.
  targetStreak,

  /// Cumulative cigarettes not smoked.
  cigarettesAvoided,

  /// How much longer the gap between cigarettes has become, in percent.
  intervalGain,

  /// The longest barrier ever actually completed, in minutes.
  longestBarrier,
}

class Achievement {
  final String id;
  final String titleKey;
  final String descriptionKey;
  final String icon; // emoji or asset key
  final AchievementKind kind;

  /// The value of [kind]'s figure at which this unlocks.
  final int threshold;

  final bool unlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
    required this.kind,
    required this.threshold,
    this.unlocked = false,
    this.unlockedAt,
  });

  Achievement copyWith({bool? unlocked, DateTime? unlockedAt}) {
    return Achievement(
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

  static Achievement fromJsonState(
    Achievement base,
    Map<String, dynamic> json,
  ) {
    return base.copyWith(
      unlocked: json['unlocked'] as bool? ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'] as String)
          : null,
    );
  }

  /// Every badge the app can award.
  ///
  /// Deliberately spread across all three figures rather than stacked on one:
  /// someone who logs every cigarette and someone who only answers tasks are
  /// both making progress, and each should have badges within reach.
  static const List<Achievement> catalog = [
    // Staying at or under target — the day-to-day discipline.
    Achievement(
      id: 'streak_1',
      titleKey: 'achievementStreak1Title',
      descriptionKey: 'achievementStreak1Desc',
      icon: '🌱',
      kind: AchievementKind.targetStreak,
      threshold: 1,
    ),
    Achievement(
      id: 'streak_3',
      titleKey: 'achievementStreak3Title',
      descriptionKey: 'achievementStreak3Desc',
      icon: '🔥',
      kind: AchievementKind.targetStreak,
      threshold: 3,
    ),
    Achievement(
      id: 'streak_7',
      titleKey: 'achievementStreak7Title',
      descriptionKey: 'achievementStreak7Desc',
      icon: '⭐',
      kind: AchievementKind.targetStreak,
      threshold: 7,
    ),
    Achievement(
      id: 'streak_30',
      titleKey: 'achievementStreak30Title',
      descriptionKey: 'achievementStreak30Desc',
      icon: '🏆',
      kind: AchievementKind.targetStreak,
      threshold: 30,
    ),
    Achievement(
      id: 'streak_90',
      titleKey: 'achievementStreak90Title',
      descriptionKey: 'achievementStreak90Desc',
      icon: '👑',
      kind: AchievementKind.targetStreak,
      threshold: 90,
    ),

    // Cigarettes not smoked — what the discipline adds up to.
    Achievement(
      id: 'avoided_20',
      titleKey: 'achievementAvoided20Title',
      descriptionKey: 'achievementAvoided20Desc',
      icon: '🚭',
      kind: AchievementKind.cigarettesAvoided,
      threshold: 20,
    ),
    Achievement(
      id: 'avoided_100',
      titleKey: 'achievementAvoided100Title',
      descriptionKey: 'achievementAvoided100Desc',
      icon: '💨',
      kind: AchievementKind.cigarettesAvoided,
      threshold: 100,
    ),
    Achievement(
      id: 'avoided_500',
      titleKey: 'achievementAvoided500Title',
      descriptionKey: 'achievementAvoided500Desc',
      icon: '🫁',
      kind: AchievementKind.cigarettesAvoided,
      threshold: 500,
    ),
    Achievement(
      id: 'avoided_1000',
      titleKey: 'achievementAvoided1000Title',
      descriptionKey: 'achievementAvoided1000Desc',
      icon: '💎',
      kind: AchievementKind.cigarettesAvoided,
      threshold: 1000,
    ),

    // A widening gap — the thing the barrier is actually training.
    Achievement(
      id: 'interval_25',
      titleKey: 'achievementInterval25Title',
      descriptionKey: 'achievementInterval25Desc',
      icon: '⏱️',
      kind: AchievementKind.intervalGain,
      threshold: 25,
    ),
    Achievement(
      id: 'interval_50',
      titleKey: 'achievementInterval50Title',
      descriptionKey: 'achievementInterval50Desc',
      icon: '⏳',
      kind: AchievementKind.intervalGain,
      threshold: 50,
    ),
    Achievement(
      id: 'interval_100',
      titleKey: 'achievementInterval100Title',
      descriptionKey: 'achievementInterval100Desc',
      icon: '🎯',
      kind: AchievementKind.intervalGain,
      threshold: 100,
    ),

    // The barrier's own natural reward — how long the longest single
    // no-smoking window ever completed actually ran.
    Achievement(
      id: 'longest_barrier_60',
      titleKey: 'achievementLongestBarrier60Title',
      descriptionKey: 'achievementLongestBarrier60Desc',
      icon: '🕐',
      kind: AchievementKind.longestBarrier,
      threshold: 60,
    ),
    Achievement(
      id: 'longest_barrier_120',
      titleKey: 'achievementLongestBarrier120Title',
      descriptionKey: 'achievementLongestBarrier120Desc',
      icon: '🌟',
      kind: AchievementKind.longestBarrier,
      threshold: 120,
    ),
  ];
}
