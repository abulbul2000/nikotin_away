/// Notification history service.
///
/// Records every notification shown by the app (with timestamp) so the user
/// can review missed notifications later in the Notifications page.
///
/// Retention rule: each notification stays visible for at least 6 hours,
/// then is automatically removed. This means a notification shown at 23:59
/// will still be visible until 05:59 the next day — day boundaries never
/// cut off notifications prematurely.

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
  }) async {
    try {
      final storage = StorageService();
      final db = await storage.database;
      final now = DateTime.now();
      final expiresAt = now.add(_retention);

      await db.insert('notification_history', {
        'id': 'notif_${now.microsecondsSinceEpoch}',
        'title': title,
        'body': body,
        'type': type,
        'receivedAt': now.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      });
    } catch (e) {
      // Best effort — never let history recording break the notification flow.
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

      final rows = await db.query(
        'notification_history',
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
        'SELECT COUNT(*) as count FROM notification_history WHERE expiresAt >= ?',
        [now],
      );

      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
