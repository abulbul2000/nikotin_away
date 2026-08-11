import '../models/task_assignment.dart';

/// What to do with a batch of tasks stuck in `pendingDelivery`.
class TaskDeliveryGateDecision {
  const TaskDeliveryGateDecision({
    required this.toDeliver,
    required this.toExpire,
  });

  /// The one task (oldest by `scheduledAt`) that should actually be shown
  /// next, or null if there is nothing waiting.
  final TaskAssignment? toDeliver;

  /// Everything beyond the two-task queue limit — closed out as `expired`
  /// and never reported to the learning engine, since a task that never
  /// reached the user is the app's own delay, not their failure.
  final List<TaskAssignment> toExpire;
}

/// Decides how many `pendingDelivery` tasks may sit in the queue at once.
///
/// A pure function on purpose: it only sorts and slices a list, and does no
/// I/O itself — the caller (`TaskAssignmentService`) is the one that reads
/// the open tasks and writes the resulting transitions, same split as
/// `discipline_protocol_service`'s planning functions.
class TaskDeliveryGate {
  /// Past this many tasks waiting in `pendingDelivery`, the oldest keeps
  /// waiting and everything past it is expired rather than piling up
  /// indefinitely — a delayed task is still owed, but an endless backlog is
  /// the same as no schedule at all.
  static const int maxQueuedTasks = 2;

  static TaskDeliveryGateDecision decide(List<TaskAssignment> pending) {
    if (pending.isEmpty) {
      return const TaskDeliveryGateDecision(toDeliver: null, toExpire: []);
    }
    final sorted = [...pending]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final toDeliver = sorted.first;
    final toExpire = sorted.length > maxQueuedTasks
        ? sorted.sublist(maxQueuedTasks)
        : const <TaskAssignment>[];
    return TaskDeliveryGateDecision(toDeliver: toDeliver, toExpire: toExpire);
  }
}
