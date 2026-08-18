class HealthMilestone {
  final String titleKey;
  final String descriptionKey;
  final Duration timeSinceQuit;
  final String icon;

  const HealthMilestone({
    required this.titleKey,
    required this.descriptionKey,
    required this.timeSinceQuit,
    required this.icon,
  });

  /// Medically-referenced smoking cessation recovery timeline
  /// (based on commonly cited CDC / WHO cessation benefit timelines).
  static const List<HealthMilestone> timeline = [
    HealthMilestone(
      titleKey: 'recoveryMin20Title',
      descriptionKey: 'recoveryMin20Desc',
      timeSinceQuit: Duration(minutes: 20),
      icon: '❤️',
    ),
    HealthMilestone(
      titleKey: 'recoveryHour12Title',
      descriptionKey: 'recoveryHour12Desc',
      timeSinceQuit: Duration(hours: 12),
      icon: '🫁',
    ),
    HealthMilestone(
      titleKey: 'recoveryDay1Title',
      descriptionKey: 'recoveryDay1Desc',
      timeSinceQuit: Duration(hours: 24),
      icon: '💓',
    ),
    HealthMilestone(
      titleKey: 'recoveryDay2Title',
      descriptionKey: 'recoveryDay2Desc',
      timeSinceQuit: Duration(hours: 48),
      icon: '👃',
    ),
    HealthMilestone(
      titleKey: 'recoveryDay3Title',
      descriptionKey: 'recoveryDay3Desc',
      timeSinceQuit: Duration(hours: 72),
      icon: '🌬️',
    ),
    HealthMilestone(
      titleKey: 'recoveryWeek2Title',
      descriptionKey: 'recoveryWeek2Desc',
      timeSinceQuit: Duration(days: 14),
      icon: '🏃',
    ),
    HealthMilestone(
      titleKey: 'recoveryMonth1Title',
      descriptionKey: 'recoveryMonth1Desc',
      timeSinceQuit: Duration(days: 30),
      icon: '😮‍💨',
    ),
    HealthMilestone(
      titleKey: 'recoveryMonth9Title',
      descriptionKey: 'recoveryMonth9Desc',
      timeSinceQuit: Duration(days: 270),
      icon: '🫀',
    ),
    HealthMilestone(
      titleKey: 'recoveryYear1Title',
      descriptionKey: 'recoveryYear1Desc',
      timeSinceQuit: Duration(days: 365),
      icon: '🎉',
    ),
    HealthMilestone(
      titleKey: 'recoveryYear5Title',
      descriptionKey: 'recoveryYear5Desc',
      timeSinceQuit: Duration(days: 365 * 5),
      icon: '🛡️',
    ),
    HealthMilestone(
      titleKey: 'recoveryYear10Title',
      descriptionKey: 'recoveryYear10Desc',
      timeSinceQuit: Duration(days: 365 * 10),
      icon: '🏅',
    ),
  ];
}
