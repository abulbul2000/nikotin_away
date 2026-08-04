import '../models/breath_badge.dart';
import '../models/breath_progress_record.dart';

/// Determines which [BreathBadge]s a breath-test history has earned. Pure
/// and DB-free like the other engines — persistence of the unlock state
/// happens one layer up (mirrors AchievementService's
/// evaluateProgress/loadAll split, but for breath-test badges).
///
/// Gürültülü işaretli kayıtlar dailyStreak/totalTests/personalRecord
/// hesaplarından dışlanır — trend istatistikleriyle aynı kural
/// (BreathTrendEngine'in doc comment'ine bakınız): gürültülü bir kayıt
/// gerçek performansı yansıtmayabilir, rozet kazandırmamalı.
class BreathBadgeEngine {
  /// Returns which [BreathBadgeKind]s are earned given the current
  /// (clean) record history. A kind appears in the result once its
  /// threshold is met — callers combine this with previously-persisted
  /// unlock state (see BreathBadgeService) so an unlock is never lost even
  /// if a later record set would no longer qualify.
  Set<BreathBadgeKind> evaluateEarnedKinds(List<BreathProgressRecord> records) {
    final clean = records.where((r) => !r.isNoisyEnvironment).toList()
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    if (clean.isEmpty) {
      return const {};
    }

    final earned = <BreathBadgeKind>{};

    earned.add(BreathBadgeKind.firstTest);

    if (clean.length >= BreathBadge.catalog
        .firstWhere((b) => b.kind == BreathBadgeKind.totalTests)
        .threshold) {
      earned.add(BreathBadgeKind.totalTests);
    }

    if (_bestDailyStreak(clean) >= BreathBadge.catalog
        .firstWhere((b) => b.kind == BreathBadgeKind.dailyStreak)
        .threshold) {
      earned.add(BreathBadgeKind.dailyStreak);
    }

    if (_hasPersonalRecordImprovement(clean)) {
      earned.add(BreathBadgeKind.personalRecord);
    }

    return earned;
  }

  /// True once the history contains at least one record whose score beats
  /// every record that came before it — i.e. a real personal best was set
  /// at some point, not just on the very first test (which trivially
  /// "beats" an empty history but isn't a meaningful improvement to
  /// celebrate).
  bool _hasPersonalRecordImprovement(List<BreathProgressRecord> cleanAscending) {
    if (cleanAscending.length < 2) {
      return false;
    }
    var best = cleanAscending.first.breathScore;
    for (var i = 1; i < cleanAscending.length; i++) {
      final score = cleanAscending[i].breathScore;
      if (score > best) {
        return true;
      }
      best = score > best ? score : best;
    }
    return false;
  }

  int _bestDailyStreak(List<BreathProgressRecord> cleanAscending) {
    final days = cleanAscending
        .map((r) => _dateOnly(r.completedAt))
        .toSet()
        .toList()
      ..sort((a, b) => a.compareTo(b));

    if (days.isEmpty) {
      return 0;
    }

    var best = 1;
    var current = 1;
    for (var i = 1; i < days.length; i++) {
      final diff = days[i].difference(days[i - 1]).inDays;
      if (diff == 1) {
        current += 1;
        if (current > best) {
          best = current;
        }
      } else {
        current = 1;
      }
    }
    return best;
  }

  DateTime _dateOnly(DateTime dateTime) {
    final local = dateTime.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
