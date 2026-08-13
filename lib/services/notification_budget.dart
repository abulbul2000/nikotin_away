/// What a notification is for.
///
/// Every notification the app sends belongs to exactly one of these, and the
/// kind is what decides whether it may be sent right now.
enum NotificationKind {
  /// A task is due. The whole programme is built on these.
  taskAlert,

  /// A task went unanswered and is being asked again.
  taskRetry,

  /// A barrier window finished; asking whether it held.
  taskConfirmation,

  /// A dose the user themselves put on the clock.
  medication,

  /// General advice for a reported condition.
  healthTip,

  /// A coaching line from the behaviour engine.
  coachCommand,

  /// "You have been sitting a while."
  sedentary,

  /// The weekly survey is due.
  weeklySurvey,
}

/// Whether the user is owed this notification or merely offered it.
enum NotificationClass {
  /// Sending it is a promise the app already made. Never suppressed, never
  /// delayed to make room for something else.
  owed,

  /// Useful, but not at any price. Subject to the daily budget and spacing.
  offered,
}

/// The single gate every notification passes through.
///
/// Fifteen separate schedulers used to decide on their own when to speak, and
/// only three of them consulted the shared spacing helper. Each one spaced its
/// own notifications sensibly, so each one looked correct in isolation, while
/// the person holding the phone got tasks, retries, coaching lines, a health
/// tip, a breath reminder and a sedentary nudge from six code paths that had
/// never heard of each other. Nothing counted the total, and nothing decided
/// what to drop when the day was already full.
///
/// This is deliberately pure: the decision is arithmetic over a small piece of
/// state, so it can be checked directly. The alternative — reading the answer
/// off a device after a day of use — is how the current behaviour survived
/// this long.
class NotificationBudget {
  const NotificationBudget();

  /// How many *offered* notifications a day, by the intensity the user chose
  /// during setup.
  ///
  /// That setting's own description promises exactly this ("how often the app
  /// will interrupt and task you during the day") and until now it changed
  /// nothing at all: the figure it fed was never read by anything.
  static int dailyBudgetFor(String intensity) {
    switch (intensity) {
      case 'gentle':
        return 2;
      case 'strict':
        return 6;
      default:
        return 4;
    }
  }

  /// Minimum time between any two notifications, whatever their kind.
  ///
  /// Applies across kinds on purpose — two notifications a minute apart are
  /// one interruption to the person receiving them, no matter which feature
  /// each came from.
  static const Duration minimumGap = Duration(minutes: 25);

  NotificationClass classOf(NotificationKind kind) {
    switch (kind) {
      // The task itself, the retry chain that chases it, and the question at
      // the end of the window are one conversation. Dropping any part leaves
      // the user with an unanswered obligation or an unclosed timer.
      case NotificationKind.taskAlert:
      case NotificationKind.taskRetry:
      case NotificationKind.taskConfirmation:
      // The user picked these times themselves for a medicine they take.
      case NotificationKind.medication:
        return NotificationClass.owed;

      case NotificationKind.healthTip:
      case NotificationKind.coachCommand:
      case NotificationKind.sedentary:
      case NotificationKind.weeklySurvey:
        return NotificationClass.offered;
    }
  }

  /// Ranks the offered kinds against each other. Lower wins.
  ///
  /// Only consulted when the budget is tight, and it reflects what the day is
  /// actually for: a missed measurement leaves a permanent hole in the trend,
  /// whereas a coaching line or a sitting reminder can wait for tomorrow
  /// without costing anything.
  int priorityOf(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.taskAlert:
      case NotificationKind.taskRetry:
      case NotificationKind.taskConfirmation:
      case NotificationKind.medication:
        return 0;
      case NotificationKind.weeklySurvey:
        return 2;
      case NotificationKind.healthTip:
        return 3;
      case NotificationKind.coachCommand:
        return 4;
      case NotificationKind.sedentary:
        return 5;
    }
  }

  /// Whether [kind] may be sent at [at].
  ///
  /// [offeredSentToday] is how many offered notifications have already gone
  /// out today; [lastSentAt] is when anything was last sent, of any kind.
  BudgetDecision decide({
    required NotificationKind kind,
    required DateTime at,
    required String intensity,
    required int offeredSentToday,
    required DateTime? lastSentAt,
    required int lowestPendingOfferedPriority,
  }) {
    if (classOf(kind) == NotificationClass.owed) {
      return const BudgetDecision.allow();
    }

    if (lastSentAt != null && at.difference(lastSentAt).abs() < minimumGap) {
      return const BudgetDecision.deny(BudgetDenial.tooSoon);
    }

    if (offeredSentToday >= dailyBudgetFor(intensity)) {
      return const BudgetDecision.deny(BudgetDenial.budgetSpent);
    }

    // Something more important is already waiting for a slot today. Yielding
    // matters because the budget is small: without this a sedentary nudge at
    // nine in the morning could spend the last slot and silence the breath
    // reminder for the rest of the day.
    if (priorityOf(kind) > lowestPendingOfferedPriority) {
      return const BudgetDecision.deny(BudgetDenial.outranked);
    }

    return const BudgetDecision.allow();
  }
}

enum BudgetDenial { tooSoon, budgetSpent, outranked }

class BudgetDecision {
  const BudgetDecision.allow() : allowed = true, denial = null;
  const BudgetDecision.deny(BudgetDenial reason)
    : allowed = false,
      denial = reason;

  final bool allowed;
  final BudgetDenial? denial;
}
