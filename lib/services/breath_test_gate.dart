/// Where the user stands on today's breath test.
enum BreathTestStanding {
  /// Already done since midnight — nothing to ask.
  doneToday,

  /// Not done today, but the last one was recent enough that putting it off
  /// is reasonable.
  due,

  /// A full day has gone by with no reading. The trend the whole programme
  /// reports on is built from these, and a gap in it cannot be filled in
  /// later — so this is the one case where "later" is not offered.
  overdue,
}

/// Decides whether to ask for a breath test, and whether the ask can be
/// declined.
///
/// Kept free of storage and widgets so the rule itself can be checked
/// directly: the timing is the whole feature, and it is easy to get a day
/// boundary subtly wrong in a way no screenshot would reveal.
class BreathTestGate {
  const BreathTestGate();

  /// After this long without a reading the prompt stops taking no for an
  /// answer.
  static const Duration overdueAfter = Duration(hours: 24);

  BreathTestStanding standing({
    required DateTime? lastCompletedAt,
    required DateTime now,
  }) {
    if (lastCompletedAt == null) {
      // Never taken one. There is no trend to protect yet, but there is also
      // nothing to build one from, so this counts as overdue rather than
      // letting a new user defer indefinitely.
      return BreathTestStanding.overdue;
    }

    final sameDay =
        lastCompletedAt.year == now.year &&
        lastCompletedAt.month == now.month &&
        lastCompletedAt.day == now.day;
    if (sameDay) {
      return BreathTestStanding.doneToday;
    }

    // Deliberately elapsed time rather than "a calendar day has turned":
    // someone who tests at 23:50 and opens the app at 00:10 has not skipped
    // anything, and being told they are overdue twenty minutes later would
    // read as the app losing track.
    if (now.difference(lastCompletedAt) >= overdueAfter) {
      return BreathTestStanding.overdue;
    }
    return BreathTestStanding.due;
  }

  /// Whether the prompt should appear at all.
  bool shouldPrompt({required DateTime? lastCompletedAt, required DateTime now}) {
    return standing(lastCompletedAt: lastCompletedAt, now: now) !=
        BreathTestStanding.doneToday;
  }

  /// Whether "later" is an option.
  bool canDefer({required DateTime? lastCompletedAt, required DateTime now}) {
    return standing(lastCompletedAt: lastCompletedAt, now: now) ==
        BreathTestStanding.due;
  }
}
