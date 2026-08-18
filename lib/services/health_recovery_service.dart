import '../models/health_milestone.dart';

class HealthRecoveryProgress {
  final List<HealthMilestone> reached;
  final HealthMilestone? next;
  final double nextProgress; // 0.0 - 1.0 towards the next milestone

  const HealthRecoveryProgress({
    required this.reached,
    required this.next,
    required this.nextProgress,
  });
}

class HealthRecoveryService {
  /// Was `computeProgress(DateTime quitDate)`, elapsed-time measured from
  /// a fixed "quit date" — this app has no such date in any real sense
  /// (gradual reduction, not abstinence; see CLAUDE.md), so that read as
  /// "20 minutes since you joined the program: heart rate normalized"
  /// regardless of whether the user smoked a cigarette five minutes ago.
  /// The recovery timeline's own milestones (CO clearance, heart rate,
  /// nicotine clearance) are physiologically measured from the *last*
  /// cigarette, so [lastSmokedAt] — the most recently logged smoking
  /// event, or null if none has ever been logged — is the only anchor
  /// that makes these claims accurate. No evidence yet reports no
  /// progress at all, the same "silence is not achievement" rule
  /// StorageService.loadReductionProgress already follows.
  HealthRecoveryProgress computeProgress(DateTime? lastSmokedAt) {
    final reached = <HealthMilestone>[];
    HealthMilestone? next;
    double nextProgress = 0;

    if (lastSmokedAt == null) {
      return const HealthRecoveryProgress(
        reached: [],
        next: null,
        nextProgress: 0,
      );
    }

    final elapsed = DateTime.now().difference(lastSmokedAt);

    for (var i = 0; i < HealthMilestone.timeline.length; i++) {
      final milestone = HealthMilestone.timeline[i];
      if (elapsed >= milestone.timeSinceQuit) {
        reached.add(milestone);
      } else {
        next = milestone;
        final previousThreshold = i == 0
            ? Duration.zero
            : HealthMilestone.timeline[i - 1].timeSinceQuit;
        final span = milestone.timeSinceQuit - previousThreshold;
        final progressed = elapsed - previousThreshold;
        nextProgress = span.inSeconds == 0
            ? 1.0
            : (progressed.inSeconds / span.inSeconds).clamp(0.0, 1.0);
        break;
      }
    }

    return HealthRecoveryProgress(
      reached: reached,
      next: next,
      nextProgress: nextProgress,
    );
  }
}
