#!/usr/bin/env python3
"""Add notification_history table and methods to storage_service.dart"""

import re

file_path = 'lib/services/storage_service.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add table name constant
if '_notificationsHistoryTable' not in content:
    # Add after _failureTriggersTable constant
    content = content.replace(
        "static const _failureTriggersTable = 'failure_triggers';",
        "static const _failureTriggersTable = 'failure_triggers';\n"
        "  static const _notificationsHistoryTable = 'notification_history';",
        1
    )

# 2. Bump version from 32 to 33
content = content.replace('version: 32,', 'version: 33,', 1)

# 3. Add _ensureNotificationsHistoryTable call in onCreate
if '_ensureNotificationsHistoryTable(db)' not in content:
    content = content.replace(
        'await _ensureFailureTriggersTable(db);\n        await _ensureIndexes(db);',
        'await _ensureFailureTriggersTable(db);\n        await _ensureNotificationsHistoryTable(db);\n        await _ensureIndexes(db);',
        1
    )

# 4. Add _ensureNotificationsHistoryTable call in onUpgrade
if 'await _ensureNotificationsHistoryTable(db);' in content:
    # Already added in onCreate, need to add in onUpgrade too
    # Find the second occurrence (in onUpgrade) - after failure triggers in onUpgrade
    content = content.replace(
        'await _ensureFailureTriggersTable(db);\n        if (oldVersion < 31)',
        'await _ensureFailureTriggersTable(db);\n        await _ensureNotificationsHistoryTable(db);\n        if (oldVersion < 31)',
        1
    )

# 5. Add the table creation method before _ensureFailureTriggersTable
method = """
  Future<void> _ensureNotificationsHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_notificationsHistoryTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT '',
        receivedAt TEXT NOT NULL,
        expiresAt TEXT NOT NULL
      )
    ''');
  }

"""

# Insert before _ensureFailureTriggersTable
content = content.replace(
    '  Future<void> _ensureFailureTriggersTable(Database db) async {',
    method + '  Future<void> _ensureFailureTriggersTable(Database db) async {',
    1
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done! Added notification_history table to storage_service.dart")
