#!/usr/bin/env python3
"""Add notification history link to settings_page.dart"""

file_path = 'lib/pages/settings_page.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add import for notifications_page
if "../pages/notifications_page.dart" not in content:
    content = content.replace(
        "import '../pages/language_selection_page.dart';",
        "import '../pages/language_selection_page.dart';\nimport '../pages/notifications_page.dart';",
        1
    )

# 2. Add _openNotifications method
open_method = """
  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

"""

# Insert before _openLanguageSettings
if "_openNotifications" not in content:
    content = content.replace(
        "  Future<void> _openLanguageSettings() async {",
        open_method + "  Future<void> _openLanguageSettings() async {",
        1
    )

# 3. Add the ListTile in the settings build method
# Add after the notifKindsSectionTitle section
notification_tile = """
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(context.t('settingsNotificationsRow')),
            subtitle: Text(context.t('settingsNotificationsRowSubtitle')),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openNotifications,
          ),
        ),
"""

# Insert after NotificationKindsCard and before settingsSectionGeneral
if "settingsNotificationsRow" not in content:
    content = content.replace(
        "        _SectionLabel(context.t('settingsSectionGeneral')),",
        notification_tile + "        _SectionLabel(context.t('settingsSectionGeneral')),",
        1
    )

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done! Added notifications link to settings_page.dart")
