/// Notification history service.
///
/// Records every notification shown by the app (with timestamp) so the user
/// can review missed notifications later in the Notifications page.
///
/// Retention rule: each notification stays visible for at least 6 hours,
/// then is automatically removed. This means a notification shown at 23:59
/// will still be visible until 05:59 the next day — day boundaries never
/// cut off notifications prematurely.
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
  static const Duration _retention = Duration(hours: 6);

  /// Record a notification that was just shown.
  static Future<void> record({
    required String title,
    required String body,
    required String type,
    String? dedupeKey,
    DateTime? receivedAt,
    DateTime? availableAt,
  }) async {
    try {
      final storage = StorageService();
      final db = await storage.database;
      final now = receivedAt ?? DateTime.now();
            final expiresAt = now.add(_retention);

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

      // Older app versions could record the same visible notification every
      // time the scheduler was rebuilt. Keep only the newest copy of each
      // notification content while retaining genuinely different events.
      await db.rawDelete('''
        DELETE FROM notification_history
        WHERE rowid NOT IN (
          SELECT MAX(rowid)
          FROM notification_history
          GROUP BY type, title, body
        )
      ''');

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
