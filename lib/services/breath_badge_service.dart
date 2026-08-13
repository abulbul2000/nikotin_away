import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engines/breath_badge_engine.dart';
import '../models/breath_badge.dart';
import '../models/breath_progress_record.dart';

/// Tracks which breath-test badges the user has unlocked. Mirrors
/// AchievementService's storage approach (SharedPreferences, not a sqflite
/// table — lightweight unlock state, no migration needed) but keeps its
/// own key/catalog since breath-test badges track different figures.
class BreathBadgeService {
  static const _prefsKey = 'breath_badges_state_v1';

  final BreathBadgeEngine _engine;

  BreathBadgeService({BreathBadgeEngine? engine})
    : _engine = engine ?? BreathBadgeEngine();

  /// Returns the full catalog merged with the persisted unlock state.
  Future<List<BreathBadge>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return BreathBadge.catalog;

    final Map<String, dynamic> stateById = {};
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      for (final entry in decoded) {
        final map = entry as Map<String, dynamic>;
        stateById[map['id'] as String] = map;
      }
    } catch (_) {
      return BreathBadge.catalog;
    }

    return BreathBadge.catalog.map((base) {
      final state = stateById[base.id];
      if (state == null) return base;
      return BreathBadge.fromJsonState(base, state);
    }).toList();
  }

  /// Unlocks any badge the current record history has earned and returns
  /// the ones newly unlocked in this call. Once unlocked, a badge stays
  /// unlocked even if a later record set would no longer qualify (e.g. the
  /// daily streak breaks) — same "earned once, kept forever" rule as
  /// AchievementService.
  Future<List<BreathBadge>> evaluateProgress(
    List<BreathProgressRecord> records,
  ) async {
    final earnedKinds = _engine.evaluateEarnedKinds(records);
    final current = await loadAll();
    final newlyUnlocked = <BreathBadge>[];

    final updated = current.map((badge) {
      if (badge.unlocked) return badge;
      if (!earnedKinds.contains(badge.kind)) return badge;
      final unlocked = badge.copyWith(
        unlocked: true,
        unlockedAt: DateTime.now(),
      );
      newlyUnlocked.add(unlocked);
      return unlocked;
    }).toList();

    if (newlyUnlocked.isNotEmpty) {
      await _save(updated);
    }
    return newlyUnlocked;
  }

  Future<void> _save(List<BreathBadge> badges) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(badges.map((b) => b.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
