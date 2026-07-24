class AdaptiveTaskOutcome {
  static const String success = 'success';
  static const String deferred = 'deferred';
  static const String smoked = 'smoked';

  /// All 3 retry attempts (5 minutes apart) went unanswered — distinct
  /// from [smoked] (an explicit "I smoked" admission) since silence isn't
  /// an admission of anything, but distinct from [deferred] too since a
  /// mandatory full-screen alert going fully unanswered for 15 minutes is
  /// a stronger failure signal than an active "not now" tap.
  static const String missed = 'missed';
}

class AdaptiveTaskState {
  final String id;
  final double selfControlScore;
  final double difficultyLevel;
  final double dailyTaskCapacity;
  final double postponeRate;
  final double movingSuccessRate;
  final double movingFailureRate;
  final double avgResponseMinutes;
  final int successStreak;
  final int failureStreak;
  final DateTime updatedAt;

  const AdaptiveTaskState({
    required this.id,
    required this.selfControlScore,
    required this.difficultyLevel,
    required this.dailyTaskCapacity,
    required this.postponeRate,
    required this.movingSuccessRate,
    required this.movingFailureRate,
    required this.avgResponseMinutes,
    required this.successStreak,
    required this.failureStreak,
    required this.updatedAt,
  });

  factory AdaptiveTaskState.initial() {
    return AdaptiveTaskState(
      id: 'default',
      selfControlScore: 35,
      difficultyLevel: 1,
      dailyTaskCapacity: 5,
      postponeRate: 0.25,
      movingSuccessRate: 0.45,
      movingFailureRate: 0.25,
      avgResponseMinutes: 7,
      successStreak: 0,
      failureStreak: 0,
      updatedAt: DateTime.now(),
    );
  }

  AdaptiveTaskState copyWith({
    String? id,
    double? selfControlScore,
    double? difficultyLevel,
    double? dailyTaskCapacity,
    double? postponeRate,
    double? movingSuccessRate,
    double? movingFailureRate,
    double? avgResponseMinutes,
    int? successStreak,
    int? failureStreak,
    DateTime? updatedAt,
  }) {
    return AdaptiveTaskState(
      id: id ?? this.id,
      selfControlScore: selfControlScore ?? this.selfControlScore,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      dailyTaskCapacity: dailyTaskCapacity ?? this.dailyTaskCapacity,
      postponeRate: postponeRate ?? this.postponeRate,
      movingSuccessRate: movingSuccessRate ?? this.movingSuccessRate,
      movingFailureRate: movingFailureRate ?? this.movingFailureRate,
      avgResponseMinutes: avgResponseMinutes ?? this.avgResponseMinutes,
      successStreak: successStreak ?? this.successStreak,
      failureStreak: failureStreak ?? this.failureStreak,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'selfControlScore': selfControlScore,
      'difficultyLevel': difficultyLevel,
      'dailyTaskCapacity': dailyTaskCapacity,
      'postponeRate': postponeRate,
      'movingSuccessRate': movingSuccessRate,
      'movingFailureRate': movingFailureRate,
      'avgResponseMinutes': avgResponseMinutes,
      'successStreak': successStreak,
      'failureStreak': failureStreak,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AdaptiveTaskState.fromJson(Map<String, dynamic> json) {
    return AdaptiveTaskState(
      id: (json['id'] as String?) ?? 'default',
      selfControlScore: (json['selfControlScore'] as num?)?.toDouble() ?? 35,
      difficultyLevel: (json['difficultyLevel'] as num?)?.toDouble() ?? 1,
      dailyTaskCapacity: (json['dailyTaskCapacity'] as num?)?.toDouble() ?? 5,
      postponeRate: (json['postponeRate'] as num?)?.toDouble() ?? 0.25,
      movingSuccessRate: (json['movingSuccessRate'] as num?)?.toDouble() ?? 0.45,
      movingFailureRate: (json['movingFailureRate'] as num?)?.toDouble() ?? 0.25,
      avgResponseMinutes: (json['avgResponseMinutes'] as num?)?.toDouble() ?? 7,
      successStreak: (json['successStreak'] as num?)?.toInt() ?? 0,
      failureStreak: (json['failureStreak'] as num?)?.toInt() ?? 0,
      updatedAt:
          DateTime.tryParse((json['updatedAt'] as String?) ?? '') ?? DateTime.now(),
    );
  }
}

class AdaptiveHourlyProfileEntry {
  final int hour;
  final double strainScore;
  final int successCount;
  final int failureCount;
  final int deferCount;
  final double avgResponseMinutes;
  final DateTime updatedAt;

  const AdaptiveHourlyProfileEntry({
    required this.hour,
    required this.strainScore,
    required this.successCount,
    required this.failureCount,
    required this.deferCount,
    required this.avgResponseMinutes,
    required this.updatedAt,
  });

  factory AdaptiveHourlyProfileEntry.initial(int hour) {
    return AdaptiveHourlyProfileEntry(
      hour: hour,
      strainScore: 50,
      successCount: 0,
      failureCount: 0,
      deferCount: 0,
      avgResponseMinutes: 7,
      updatedAt: DateTime.now(),
    );
  }

  AdaptiveHourlyProfileEntry copyWith({
    int? hour,
    double? strainScore,
    int? successCount,
    int? failureCount,
    int? deferCount,
    double? avgResponseMinutes,
    DateTime? updatedAt,
  }) {
    return AdaptiveHourlyProfileEntry(
      hour: hour ?? this.hour,
      strainScore: strainScore ?? this.strainScore,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      deferCount: deferCount ?? this.deferCount,
      avgResponseMinutes: avgResponseMinutes ?? this.avgResponseMinutes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hour': hour,
      'strainScore': strainScore,
      'successCount': successCount,
      'failureCount': failureCount,
      'deferCount': deferCount,
      'avgResponseMinutes': avgResponseMinutes,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AdaptiveHourlyProfileEntry.fromJson(Map<String, dynamic> json) {
    return AdaptiveHourlyProfileEntry(
      hour: (json['hour'] as num?)?.toInt() ?? 0,
      strainScore: (json['strainScore'] as num?)?.toDouble() ?? 50,
      successCount: (json['successCount'] as num?)?.toInt() ?? 0,
      failureCount: (json['failureCount'] as num?)?.toInt() ?? 0,
      deferCount: (json['deferCount'] as num?)?.toInt() ?? 0,
      avgResponseMinutes: (json['avgResponseMinutes'] as num?)?.toDouble() ?? 7,
      updatedAt:
          DateTime.tryParse((json['updatedAt'] as String?) ?? '') ?? DateTime.now(),
    );
  }
}

class AdaptiveTaskEvent {
  final String id;
  final String taskTitle;
  final DateTime scheduledAt;
  final DateTime respondedAt;
  final String outcome;
  final int plannedDurationMinutes;
  final int responseDelayMinutes;
  final int hourBucket;

  const AdaptiveTaskEvent({
    required this.id,
    required this.taskTitle,
    required this.scheduledAt,
    required this.respondedAt,
    required this.outcome,
    required this.plannedDurationMinutes,
    required this.responseDelayMinutes,
    required this.hourBucket,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskTitle': taskTitle,
      'scheduledAt': scheduledAt.toIso8601String(),
      'respondedAt': respondedAt.toIso8601String(),
      'outcome': outcome,
      'plannedDurationMinutes': plannedDurationMinutes,
      'responseDelayMinutes': responseDelayMinutes,
      'hourBucket': hourBucket,
      'createdAt': respondedAt.toIso8601String(),
    };
  }
}

class AdaptiveTaskPlanItem {
  final DateTime scheduledAt;
  final int durationMinutes;
  final String taskTitle;

  const AdaptiveTaskPlanItem({
    required this.scheduledAt,
    required this.durationMinutes,
    required this.taskTitle,
  });

  Map<String, dynamic> toJson() {
    return {
      'scheduledAt': scheduledAt.toIso8601String(),
      'durationMinutes': durationMinutes,
      'taskTitle': taskTitle,
    };
  }

  factory AdaptiveTaskPlanItem.fromJson(Map<String, dynamic> json) {
    return AdaptiveTaskPlanItem(
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      taskTitle: json['taskTitle'] as String,
    );
  }
}

class AdaptiveTaskPlan {
  final int targetTaskCount;
  final int baseDurationMinutes;
  final List<AdaptiveTaskPlanItem> items;

  const AdaptiveTaskPlan({
    required this.targetTaskCount,
    required this.baseDurationMinutes,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'targetTaskCount': targetTaskCount,
      'baseDurationMinutes': baseDurationMinutes,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory AdaptiveTaskPlan.fromJson(Map<String, dynamic> json) {
    return AdaptiveTaskPlan(
      targetTaskCount: (json['targetTaskCount'] as num).toInt(),
      baseDurationMinutes: (json['baseDurationMinutes'] as num).toInt(),
      items: ((json['items'] as List?) ?? const [])
          .map((raw) => AdaptiveTaskPlanItem.fromJson(raw as Map<String, dynamic>))
          .toList(),
    );
  }
}
