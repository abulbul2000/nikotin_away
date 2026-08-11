/// Decides whether a mentor-granted "relief" (a temporary easing of the
/// daily plan, offered after the user taps "Zorlanıyorum" on the mentor
/// card) is currently active, and by how much.
///
/// Pure, no I/O — StorageService reads the relief timestamps from
/// SharedPreferences and feeds them in here; this class never touches
/// storage itself.
abstract final class MentorReliefService {
  /// Halves (rounded up) the daily task target while a "Görevleri azalt"
  /// relief is active, never dropping below 1.
  ///
  /// [reliefUntil] is the exclusive end of the relief window — always set
  /// to start the day *after* it was granted, so today's already-planned
  /// tasks are never touched. Null means no relief was ever granted.
  static int applyTaskReliefIfActive({
    required int baseCount,
    required DateTime now,
    required DateTime? reliefUntil,
  }) {
    if (reliefUntil == null || !now.isBefore(reliefUntil)) {
      return baseCount;
    }
    return (baseCount * 0.5).ceil().clamp(1, baseCount);
  }

  /// Cuts today's barrier by 30% while a same-day "Bariyeri gevşet" relief
  /// is active, clamped above [minBarrierMinutes].
  ///
  /// [reliefDate] must match [now]'s calendar day exactly (not just be in
  /// the past) — the relief is explicitly single-day, not open-ended, and
  /// is always granted for the day *after* the mentor reply, so a relief
  /// dated today was requested yesterday and is legitimately still active.
  static int applyBarrierReliefIfActive({
    required int baseMinutes,
    required DateTime now,
    required DateTime? reliefDate,
    required int minBarrierMinutes,
  }) {
    final isToday =
        reliefDate != null &&
        reliefDate.year == now.year &&
        reliefDate.month == now.month &&
        reliefDate.day == now.day;
    if (!isToday) {
      return baseMinutes;
    }
    return (baseMinutes * 0.7).round().clamp(minBarrierMinutes, baseMinutes);
  }
}
