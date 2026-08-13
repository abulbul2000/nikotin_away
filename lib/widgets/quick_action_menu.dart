import 'package:flutter/material.dart';

import '../core/app_texts.dart';

/// The 4 actions reachable from the floating button, the AppBar's SOS
/// button, and (natively) the launcher icon's long-press shortcuts — one
/// menu, three entry points, so a user reaches the same options no matter
/// which one they used. Order matches what the shortcuts.xml exposes
/// (Android allows at most 4 static shortcuts), so adding a 5th action here
/// would need a shortcuts.xml rethink, not just a new case.
enum QuickAction { smokedNow, craving, selfChallenge, openApp }

/// Bottom sheet listing [QuickAction]s in a fixed order — smoked-now first
/// (the single most time-sensitive log, per the product's "log the moment
/// it happens" design), then craving support, then a self-started
/// challenge, then a plain "open app" fallback (mirrors what a launcher
/// icon tap alone would have done, for the shortcut-menu entry point).
Future<QuickAction?> showQuickActionMenu(BuildContext context) {
  return showModalBottomSheet<QuickAction>(
    context: context,
    backgroundColor: const Color(0xFF0D1B2A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _QuickActionTile(
              key: const ValueKey('quick_action_smoked_now'),
              icon: Icons.smoking_rooms,
              label: sheetContext.t('quickActionSmokedNow'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(QuickAction.smokedNow),
            ),
            _QuickActionTile(
              key: const ValueKey('quick_action_craving'),
              icon: Icons.sos,
              iconColor: Colors.redAccent,
              label: sheetContext.t('cravingSosButton'),
              onTap: () => Navigator.of(sheetContext).pop(QuickAction.craving),
            ),
            _QuickActionTile(
              key: const ValueKey('quick_action_self_challenge'),
              icon: Icons.timer_outlined,
              label: sheetContext.t('quickActionSelfChallenge'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(QuickAction.selfChallenge),
            ),
            _QuickActionTile(
              key: const ValueKey('quick_action_open_app'),
              icon: Icons.home_outlined,
              label: sheetContext.t('quickActionOpenApp'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(QuickAction.openApp),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Duration choices offered before a self-challenge starts. Mirrors the
/// range a user would sensibly want between cigarettes — 15 minutes is the
/// shortest that still feels like a real interval, 60 the longest that
/// doesn't need a whole separate planning flow.
const List<int> selfChallengeDurationOptions = [15, 30, 45, 60];

/// Bottom sheet of duration choices, shown after [QuickAction.selfChallenge]
/// is picked. Returns null if dismissed without choosing.
Future<int?> showSelfChallengeDurationMenu(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: const Color(0xFF0D1B2A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              child: Text(
                sheetContext.t('selfChallengeDurationPrompt'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final minutes in selfChallengeDurationOptions)
              _QuickActionTile(
                key: ValueKey('self_challenge_duration_$minutes'),
                icon: Icons.timer_outlined,
                label: sheetContext
                    .t('selfChallengeDurationOption')
                    .replaceAll('{minutes}', '$minutes'),
                onTap: () => Navigator.of(sheetContext).pop(minutes),
              ),
          ],
        ),
      ),
    ),
  );
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    super.key,
    required this.icon,
    this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.white70),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }
}
