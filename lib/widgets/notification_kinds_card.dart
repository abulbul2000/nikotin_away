import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../services/notification_budget.dart';
import '../services/storage_service.dart';

/// Lets the user switch individual notification kinds on or off.
///
/// Only the *offered* kinds appear — a due task or a dose the user scheduled
/// themselves is not a preference, it is a promise the app already made
/// (see [NotificationBudget]). Turning one off here is read directly by
/// [NotificationService]'s shared budget gate before anything of that kind is
/// scheduled, so it takes effect immediately, not just for notifications
/// created after the change.
class NotificationKindsCard extends StatefulWidget {
  const NotificationKindsCard({super.key, this.storageService});

  /// Overridable so widget tests can supply a synchronous fake — sqflite's
  /// real I/O never resolves inside flutter_test's fake-async pump loop,
  /// which otherwise leaves the card stuck on its loading state forever.
  final StorageService? storageService;

  @override
  State<NotificationKindsCard> createState() => _NotificationKindsCardState();
}

class _NotificationKindsCardState extends State<NotificationKindsCard> {
  late final StorageService _storageService =
      widget.storageService ?? StorageService();

  /// Every kind the user actually has a choice about, ordered the same way
  /// the budget prioritises them — the most consequential (a missed reading
  /// that can never be retaken) first.
  static const _offeredKinds = <NotificationKind>[
    NotificationKind.breathTest,
    NotificationKind.weeklySurvey,
    NotificationKind.healthTip,
    NotificationKind.coachCommand,
    NotificationKind.sedentary,
  ];

  final Map<NotificationKind, bool> _enabled = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = <NotificationKind, bool>{};
    for (final kind in _offeredKinds) {
      results[kind] = await _storageService.isNotificationKindEnabled(
        kind.name,
      );
    }
    if (!mounted) return;
    setState(() {
      _enabled
        ..clear()
        ..addAll(results);
      _loading = false;
    });
  }

  Future<void> _toggle(NotificationKind kind, bool value) async {
    setState(() => _enabled[kind] = value);
    await _storageService.setNotificationKindEnabled(kind.name, value);
  }

  String _titleKey(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.breathTest:
        return 'notifKindBreathTest';
      case NotificationKind.weeklySurvey:
        return 'notifKindWeeklySurvey';
      case NotificationKind.healthTip:
        return 'notifKindHealthTip';
      case NotificationKind.coachCommand:
        return 'notifKindCoachCommand';
      case NotificationKind.sedentary:
        return 'notifKindSedentary';
      case NotificationKind.taskAlert:
      case NotificationKind.taskRetry:
      case NotificationKind.taskConfirmation:
      case NotificationKind.medication:
        // Owed kinds never reach this widget — see _offeredKinds above —
        // but the switch must stay exhaustive so a new NotificationKind
        // forces a decision here rather than silently falling through.
        throw StateError('$kind is owed, not offered — has no toggle');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('notifKindsTitle'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              context.t('notifKindsHint'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
            ),
            const SizedBox(height: 8),
            for (final kind in _offeredKinds)
              SwitchListTile(
                key: ValueKey('notification_kind_${kind.name}'),
                contentPadding: EdgeInsets.zero,
                title: Text(context.t(_titleKey(kind))),
                value: _enabled[kind] ?? true,
                onChanged: (value) => _toggle(kind, value),
              ),
          ],
        ),
      ),
    );
  }
}
