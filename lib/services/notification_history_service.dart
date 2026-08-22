/// Notification history service.
///
/// Records every notification shown by the app (with timestamp) so the user
/// can review missed notifications later in the Notifications page.
///
/// Retention rule: every notification stays in the in-app archive for
/// 24 hours from its received/scheduled delivery time, then is removed.
library;

import '../services/storage_service.dart';

/// A single notification history entry.
class NotificationHistoryEntry {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime receivedAt;

  const NotificationHistoryEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.receivedAt,
  });

  factory NotificationHistoryEntry.fromMap(Map<String, dynamic> map) {
    return NotificationHistoryEntry(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: map['type'] as String? ?? '',
      receivedAt: DateTime.parse(map['receivedAt'] as String),
    );
  }
}

/// Manages the in-app notification history.
class NotificationHistoryService {
  static const Duration _retention = Duration(hours: 24);

  // Mandatory-task and medication events remain persisted in their own
  // task/medication tables for the behavior engine, but are intentionally not
  // shown in the user-facing Notifications archive. The archive is reserved
  // for useful informational content such as health tips and reports.
  static const Set<String> _archiveExcludedTypes = <String>{
    'task_start',
    'task_followup',
    'task_postpone',
    'task_confirm',
    'medication_reminder',
  };

  /// Record a notification that was just shown.
  static Future<void> record({
    required String title,
    required String body,
    required String type,
    String? dedupeKey,
    DateTime? receivedAt,
    DateTime? availableAt,
  }) async {
    if (_archiveExcludedTypes.contains(type)) {
      return;
    }
    try {
      final storage = StorageService();
      final db = await storage.database;
      final now = receivedAt ?? DateTime.now();
      // Scheduled local notifications are inserted before Android displays
      // them. The archive must remain available for 24 hours from the time
      // the notification becomes visible, not from the earlier scheduling
      // call; otherwise late-day scheduling can shorten its retention.
      final archiveStart = availableAt ?? now;
      final expiresAt = archiveStart.add(_retention);

      if (dedupeKey != null && dedupeKey.isNotEmpty) {
        final existing = await db.query(
          'notification_history',
          columns: ['id'],
          where: 'dedupeKey = ? AND expiresAt >= ?',
          whereArgs: [dedupeKey, now.toIso8601String()],
          orderBy: 'receivedAt DESC',
          limit: 1,
        );
        if (existing.isNotEmpty) {
          await db.update(
            'notification_history',
            {
              'title': title,
              'body': body,
              'type': type,
              'receivedAt': now.toIso8601String(),
              'expiresAt': expiresAt.toIso8601String(),
              'availableAt': (availableAt ?? now).toIso8601String(),
              'dedupeKey': dedupeKey,
            },
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
          return;
        }
      }

      await db.insert('notification_history', {
        'id': 'notif_${now.microsecondsSinceEpoch}',
        'title': title,
        'body': body,
        'type': type,
        'dedupeKey': dedupeKey,
        'receivedAt': now.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'availableAt': (availableAt ?? now).toIso8601String(),
      });
    } catch (e) {
      // Best effort — never let history recording break the notification flow.
    }
  }

  /// Marks a notification as delivered after the user presses the full-screen
  /// advice acknowledgement button.
  static Future<void> markAcknowledged({required String dedupeKey}) async {
    if (dedupeKey.isEmpty) return;
    try {
      final db = await StorageService().database;
      await db.update(
        'notification_history',
        {'acknowledgedAt': DateTime.now().toIso8601String()},
        where: 'dedupeKey = ?',
        whereArgs: [dedupeKey],
      );
    } catch (_) {
      // Acknowledgement is best effort; the advice page must still close.
    }
  }

  /// Load all non-expired notification entries, newest first.
  static Future<List<NotificationHistoryEntry>> loadEntries() async {
    try {
      final storage = StorageService();
      final db = await storage.database;
      final now = DateTime.now().toIso8601String();

      // Remove expired entries first
      await db.delete(
        'notification_history',
        where: 'expiresAt < ?',
        whereArgs: [now],
      );

      // Do not deduplicate by visible content here. Two health tips can
      // legitimately have the same title/body on different days, and the
      // product requirement is to archive every delivered notification.
      // Explicit dedupeKey handling in record() is the only deduplication
      // allowed, and it is limited to the same active notification event.

      final rows = await db.query(
        'notification_history',
        where: 'availableAt IS NULL OR availableAt <= ?',
        whereArgs: [now],
        orderBy: 'receivedAt DESC',
      );

      return rows
          .map((row) => NotificationHistoryEntry.fromMap(row))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get count of non-expired notifications.
  static Future<int> getUnreadCount() async {
    try {
      final storage = StorageService();
      final db = await storage.database;
      final now = DateTime.now().toIso8601String();

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM notification_history '
        'WHERE expiresAt >= ? AND (availableAt IS NULL OR availableAt <= ?)',
        [now, now],
      );

      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
