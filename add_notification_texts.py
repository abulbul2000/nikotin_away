#!/usr/bin/env python3
"""Add notification-related text keys to app_texts.dart"""

file_path = 'lib/core/app_texts.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# New keys to add to _tr (Turkish)
tr_keys = """
    'notificationsPageTitle': 'Bildirimler',
    'notificationsEmpty': 'Son 6 saat icinde bildirim yok',
    'settingsNotificationsRow': 'Bildirim Gecmisi',
    'settingsNotificationsRowSubtitle': 'Son bildirimlerini goruntule',
"""

# New keys to add to _en (English)
en_keys = """
    'notificationsPageTitle': 'Notifications',
    'notificationsEmpty': 'No notifications in the last 6 hours',
    'settingsNotificationsRow': 'Notification History',
    'settingsNotificationsRowSubtitle': 'View your recent notifications',
"""

# Add to _tr map (before the closing }; of _tr)
# Find the end of _tr map
tr_end = content.find("  };\n  // English - Full translation")
if tr_end != -1:
    # Insert before the closing };
    insert_pos = content.rfind('\n', 0, tr_end)
    content = content[:insert_pos] + tr_keys + content[insert_pos:]

# Add to _en map (before the closing }; of _en)
# Find the end of _en map - look for the pattern after _en keys
en_end_marker = "  };\n  // All 40 languages"
en_end = content.find(en_end_marker)
if en_end != -1:
    insert_pos = content.rfind('\n', 0, en_end)
    content = content[:insert_pos] + en_keys + content[insert_pos:]

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done! Added notification text keys")
