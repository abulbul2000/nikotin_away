/// What shape a task's completion takes.
///
/// Kept as string constants, not an enum, to match [TaskLifecycleState] and
/// survive round-tripping through SQLite without a migration every time the
/// set grows. Lives in its own file so both `task_assignment.dart` and
/// `adaptive_task_models.dart` can import it without creating a cycle
/// between them.
class TaskKind {
  /// The existing "don't smoke for N minutes" window.
  static const String noSmokeWindow = 'no_smoke_window';

  /// A short "still holding on?" check-in — see [TaskAssignment.isCheckIn].
  static const String checkIn = 'check_in';

  /// The pre-sleep routine: breath test, cough test, an optional smoking
  /// count discrepancy question, then a daily progress report. Completing it
  /// has no countdown or barrier to run, unlike [noSmokeWindow].
  static const String sleepRoutine = 'sleep_routine';
}
