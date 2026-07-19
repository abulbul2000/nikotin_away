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
  HealthRecoveryProgress computeProgress(DateTime quitDate) {
    final reached = <HealthMilestone>[];
    HealthMilestone? next;
    double nextProgress = 0;

    final elapsed = DateTime.now().difference(quitDate);

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
