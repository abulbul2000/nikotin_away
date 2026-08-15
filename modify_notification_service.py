#!/usr/bin/env python3
"""Modify notification_service.dart to:
1. Add import for notification_history_service
2. Add record call after each notification show
3. Add route for notifications page
"""

file_path = 'lib/services/notification_service.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add import for notification_history_service (after other service imports)
if "notification_history_service" not in content:
    content = content.replace(
        "import 'notification_budget.dart';",
        "import 'notification_budget.dart';\nimport 'notification_history_service.dart';",
        1
    )

# 2. Add import for notifications_page
if "../pages/notifications_page.dart" not in content:
    content = content.replace(
        "import '../pages/craving_sos_page.dart';",
        "import '../pages/craving_sos_page.dart';\nimport '../pages/notifications_page.dart';",
        1
    )

# 3. Add a helper method to record notification history
record_method = """
  /// Records a notification in the history for the Notifications page.
  /// Called after every notification is shown.
  static void _recordNotificationHistory({
    required String title,
    required String body,
    required String type,
  }) {
    unawaited(NotificationHistoryService.record(
      title: title,
      body: body,
      type: type,
    ));
  }

"""

# Insert after the _pushNotificationRoute method
if "_recordNotificationHistory" not in content:
    content = content.replace(
        "  static const String _typeBreath = 'breath';",
        record_method + "  static const String _typeBreath = 'breath';",
        1
    )

# 4. Add notifications page route in _processNotificationResponse
# Add a check for 'notifications' type at the beginning of the method
notifications_route = """
    // Navigate to Notifications page when tapped
    if (type == 'notifications') {
      if (allowNavigation) {
        final context = _navigatorKey?.currentContext;
        if (context != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsPage()),
          );
        }
      }
      return;
    }

"""

# Insert after the payload decode check
if "// Navigate to Notifications page" not in content:
    content = content.replace(
        "    final type = payload['type'];\n    if (type == _typeBreath && allowNavigation)",
        "    final type = payload['type'];\n" + notifications_route + "    if (type == _typeBreath && allowNavigation)",
        1
    )

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done! Modified notification_service.dart")
