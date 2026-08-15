#!/usr/bin/env python3
"""Add notification-related text keys to app_texts.dart"""

file_path = 'lib/core/app_texts.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find line 1883 (loginRestoreSuccess in _tr) and add after it
# Find line 3770 (loginRestoreSuccess in _en) and add after it

new_lines = []
for i, line in enumerate(lines):
    new_lines.append(line)
    if "'loginRestoreSuccess': '{count} kayıt geri yüklendi.'," in line:
        new_lines.append("    'notificationsPageTitle': 'Bildirimler',\n")
        new_lines.append("    'notificationsEmpty': 'Son 6 saat icinde bildirim yok',\n")
        new_lines.append("    'settingsNotificationsRow': 'Bildirim Gecmisi',\n")
        new_lines.append("    'settingsNotificationsRowSubtitle': 'Son bildirimlerini goruntule',\n")
    elif "'loginRestoreSuccess': '{count} records restored.'," in line:
        new_lines.append("    'notificationsPageTitle': 'Notifications',\n")
        new_lines.append("    'notificationsEmpty': 'No notifications in the last 6 hours',\n")
        new_lines.append("    'settingsNotificationsRow': 'Notification History',\n")
        new_lines.append("    'settingsNotificationsRowSubtitle': 'View your recent notifications',\n")

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Done!")
