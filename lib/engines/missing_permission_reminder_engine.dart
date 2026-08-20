/// Decides which missing permission (if any) should be re-offered right now.
///
/// Pure logic — no I/O, no `DateTime.now()` calls baked in — so the actual
/// permission-status reads and dialog live entirely in the calling widget.
/// The rule per permission: never ask again once the user checked "don't
/// show again" on a decline; otherwise re-offer once the snooze window
/// (set on every postpone AND every plain decline) has passed.
class MissingPermissionReminderEngine {
  const MissingPermissionReminderEngine();

  static const Duration snoozeDuration = Duration(days: 3);

  /// Picks the first permission (in [candidates] order) that is still
  /// missing, not permanently dismissed, and past its snooze window.
  /// Returns null when nothing is due — most days, for most users.
  String? nextPermissionDue({
    required List<String> candidates,
    required Set<String> grantedPermissionIds,
    required Set<String> neverAskAgainPermissionIds,
    required Map<String, DateTime> snoozedUntilByPermissionId,
    required DateTime now,
  }) {
    for (final id in candidates) {
      if (grantedPermissionIds.contains(id)) continue;
      if (neverAskAgainPermissionIds.contains(id)) continue;
      final snoozedUntil = snoozedUntilByPermissionId[id];
      if (snoozedUntil != null && now.isBefore(snoozedUntil)) continue;
      return id;
    }
    return null;
  }
}
