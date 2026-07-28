import 'adaptive_task_models.dart';

/// Where a task currently stands.
///
/// Strings rather than an enum to match [AdaptiveTaskOutcome] and to survive
/// round-tripping through SQLite without a migration every time the set
/// grows.
class TaskLifecycleState {
  /// In today's plan, not yet due.
  static const String planned = 'planned';

  /// Due, but held back because showing it now would land badly — the user is
  /// gaming, driving, or has Do Not Disturb on. Still owed to them.
  static const String pendingDelivery = 'pending_delivery';

  /// Shown, waiting for an answer.
  static const String delivered = 'delivered';

  /// Went unanswered; on attempt 2 or 3.
  static const String retrying = 'retrying';

  /// Snoozed for a few minutes at the user's request.
  static const String postponed = 'postponed';

  /// The user hit SOS. The task is suspended, not cancelled — the breathing
  /// exercise runs and then hands them back to it.
  static const String sosActive = 'sos_active';

  /// Accepted; the no-smoking window is running.
  static const String accepted = 'accepted';

  /// The window elapsed and we've asked whether they got through it.
  static const String awaitingConfirmation = 'awaiting_confirmation';

  static const String succeeded = 'succeeded';
  static const String failedDeclined = 'failed_declined';
  static const String failedSmoked = 'failed_smoked';
  static const String failedMissed = 'failed_missed';

  /// Never delivered, because the moment it was aimed at had passed by the
  /// time the app could show it. Deliberately kept out of the learning
  /// signal: this is the system's own delay, not the user's failure.
  static const String expired = 'expired';

  static const Set<String> terminal = {
    succeeded,
    failedDeclined,
    failedSmoked,
    failedMissed,
    expired,
  };

  /// How a finished task should be reported to the learning engine, or null
  /// when it shouldn't be reported at all.
  static String? outcomeFor(String state) {
    switch (state) {
      case succeeded:
        return AdaptiveTaskOutcome.success;
      case failedSmoked:
      case failedDeclined:
        // Declining is scored the same as an admission. The user asked for
        // this: refusing the task is treated as intending to smoke, so the
        // barrier stops growing on the strength of tasks that were simply
        // turned down.
        return AdaptiveTaskOutcome.smoked;
      case failedMissed:
        return AdaptiveTaskOutcome.missed;
      default:
        return null;
    }
  }
}

/// Why a task was held back from delivery.
class TaskGateReason {
  static const String doNotDisturb = 'dnd';
  static const String gaming = 'gaming';
  static const String driving = 'driving';
  static const String fullscreen = 'fullscreen';
}

/// A single no-smoking task, from planning through to its outcome.
///
/// Before this existed a "task" was just the string `ADAPTIVE_NO_SMOKE:45`
/// travelling inside a notification payload. That was enough while the only
/// question was "did they tap done?", but it can't hold a running countdown,
/// remember that a task was postponed twice, or know where to return after a
/// breathing exercise. Everything the flow needs to remember lives here; the
/// notification and the overlay are just its current presentation.
class TaskAssignment {
  final String id;

  /// Local calendar day this belongs to, `YYYY-MM-DD`. Used for the daily
  /// quota without having to reason about timezones at query time.
  final String planDate;

  /// The canonical `ADAPTIVE_NO_SMOKE:<minutes>` form, kept so existing text
  /// localisation keeps working unchanged.
  final String canonicalTitle;

  final int durationMinutes;
  final DateTime scheduledAt;
  final String state;

  final DateTime? deliveredAt;
  final DateTime? respondedAt;
  final DateTime? barrierStartedAt;
  final DateTime? barrierEndsAt;

  /// 1-3. The retry chain gives up after the third.
  final int attemptCount;

  /// Capped, so postponing can't be used to run the clock out on a task.
  final int postponeCount;
  final int totalPostponedMinutes;

  /// How often delivery was held back, and why the last one was.
  final int gateDeferCount;
  final String? gateReason;

  /// Also capped: SOS must stay an escape from a craving, not an escape from
  /// the task.
  final int sosCount;
  final int sosTotalMinutes;

  /// Correlates with the native watchdog that catches silence.
  final String? watchdogId;
  final int? notificationId;

  const TaskAssignment({
    required this.id,
    required this.planDate,
    required this.canonicalTitle,
    required this.durationMinutes,
    required this.scheduledAt,
    required this.state,
    this.deliveredAt,
    this.respondedAt,
    this.barrierStartedAt,
    this.barrierEndsAt,
    this.attemptCount = 1,
    this.postponeCount = 0,
    this.totalPostponedMinutes = 0,
    this.gateDeferCount = 0,
    this.gateReason,
    this.sosCount = 0,
    this.sosTotalMinutes = 0,
    this.watchdogId,
    this.notificationId,
  });

  bool get isTerminal => TaskLifecycleState.terminal.contains(state);

  /// What the learning engine should be told, or null if nothing.
  String? get outcome => TaskLifecycleState.outcomeFor(state);

  TaskAssignment copyWith({
    String? state,
    DateTime? deliveredAt,
    DateTime? respondedAt,
    DateTime? barrierStartedAt,
    DateTime? barrierEndsAt,
    int? attemptCount,
    int? postponeCount,
    int? totalPostponedMinutes,
    int? gateDeferCount,
    String? gateReason,
    int? sosCount,
    int? sosTotalMinutes,
    String? watchdogId,
    int? notificationId,
    DateTime? scheduledAt,
  }) {
    return TaskAssignment(
      id: id,
      planDate: planDate,
      canonicalTitle: canonicalTitle,
      durationMinutes: durationMinutes,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      state: state ?? this.state,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      respondedAt: respondedAt ?? this.respondedAt,
      barrierStartedAt: barrierStartedAt ?? this.barrierStartedAt,
      barrierEndsAt: barrierEndsAt ?? this.barrierEndsAt,
      attemptCount: attemptCount ?? this.attemptCount,
      postponeCount: postponeCount ?? this.postponeCount,
      totalPostponedMinutes:
          totalPostponedMinutes ?? this.totalPostponedMinutes,
      gateDeferCount: gateDeferCount ?? this.gateDeferCount,
      gateReason: gateReason ?? this.gateReason,
      sosCount: sosCount ?? this.sosCount,
      sosTotalMinutes: sosTotalMinutes ?? this.sosTotalMinutes,
      watchdogId: watchdogId ?? this.watchdogId,
      notificationId: notificationId ?? this.notificationId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'planDate': planDate,
      'canonicalTitle': canonicalTitle,
      'durationMinutes': durationMinutes,
      'scheduledAt': scheduledAt.toIso8601String(),
      'state': state,
      'deliveredAt': deliveredAt?.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
      'barrierStartedAt': barrierStartedAt?.toIso8601String(),
      'barrierEndsAt': barrierEndsAt?.toIso8601String(),
      'attemptCount': attemptCount,
      'postponeCount': postponeCount,
      'totalPostponedMinutes': totalPostponedMinutes,
      'gateDeferCount': gateDeferCount,
      'gateReason': gateReason,
      'sosCount': sosCount,
      'sosTotalMinutes': sosTotalMinutes,
      'watchdogId': watchdogId,
      'notificationId': notificationId,
    };
  }

  factory TaskAssignment.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? value) {
      final raw = value?.toString();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return TaskAssignment(
      id: json['id'] as String,
      planDate: json['planDate'] as String,
      canonicalTitle: json['canonicalTitle'] as String,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
      scheduledAt: parse(json['scheduledAt']) ?? DateTime.now(),
      state: json['state'] as String? ?? TaskLifecycleState.planned,
      deliveredAt: parse(json['deliveredAt']),
      respondedAt: parse(json['respondedAt']),
      barrierStartedAt: parse(json['barrierStartedAt']),
      barrierEndsAt: parse(json['barrierEndsAt']),
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 1,
      postponeCount: (json['postponeCount'] as num?)?.toInt() ?? 0,
      totalPostponedMinutes:
          (json['totalPostponedMinutes'] as num?)?.toInt() ?? 0,
      gateDeferCount: (json['gateDeferCount'] as num?)?.toInt() ?? 0,
      gateReason: json['gateReason'] as String?,
      sosCount: (json['sosCount'] as num?)?.toInt() ?? 0,
      sosTotalMinutes: (json['sosTotalMinutes'] as num?)?.toInt() ?? 0,
      watchdogId: json['watchdogId'] as String?,
      notificationId: (json['notificationId'] as num?)?.toInt(),
    );
  }
}
