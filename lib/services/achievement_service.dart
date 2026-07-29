import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import '../models/reduction_progress.dart';

/// Tracks which badges the user has unlocked based on consecutive
/// smoke-free days. Persists state locally via SharedPreferences so it
/// stays lightweight and doesn't require a schema migration on the
/// existing sqflite database.
class AchievementService {
  static const _prefsKey = 'achievements_state_v1';

  /// Returns the full catalog merged with the persisted unlock state.
  Future<List<Achievement>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return Achievement.catalog;

    final Map<String, dynamic> stateById = {};
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      for (final entry in decoded) {
        final map = entry as Map<String, dynamic>;
        stateById[map['id'] as String] = map;
      }
    } catch (_) {
      return Achievement.catalog;
    }

    return Achievement.catalog.map((base) {
      final state = stateById[base.id];
      if (state == null) return base;
      return Achievement.fromJsonState(base, state);
    }).toList();
  }

  /// Unlocks any badge the user's current reduction figures have earned and
  /// returns the ones unlocked in this call (useful for a celebratory
  /// dialog).
  ///
  /// Previously took a smoke-free day count that was really just calendar
  /// days since the quit date, so badges arrived for doing nothing.
  Future<List<Achievement>> evaluateProgress(ReductionProgress progress) async {
    final current = await loadAll();
    final newlyUnlocked = <Achievement>[];

    final updated = current.map((achievement) {
      if (achievement.unlocked) return achievement;
      if (currentValueFor(achievement.kind, progress) < achievement.threshold) {
        return achievement;
      }
      final unlocked = achievement.copyWith(
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

  /// The user's standing on the figure a badge of [kind] is measured against.
  /// Exposed so the badge grid can show "38 / 100" without duplicating the
  /// mapping.
  static int currentValueFor(AchievementKind kind, ReductionProgress progress) {
    switch (kind) {
      case AchievementKind.targetStreak:
        return progress.targetStreakDays;
      case AchievementKind.cigarettesAvoided:
        return progress.cigarettesAvoided;
      case AchievementKind.intervalGain:
        return (progress.intervalProgress * 100).round();
    }
  }

  Future<void> _save(List<Achievement> achievements) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(achievements.map((a) => a.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
