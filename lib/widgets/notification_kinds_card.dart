import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../services/notification_budget.dart';
import '../services/notification_service.dart';
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
    NotificationKind.weeklySurvey,
    NotificationKind.healthTip,
    NotificationKind.coachCommand,
    NotificationKind.sedentary,
  ];

  /// Matches NotificationService's user-facing maximum. Zero means the user
  /// explicitly wants no optional health-tip notifications.
  static const _maxDailyHealthTips = 5;

  final Map<NotificationKind, bool> _enabled = {};
  int _dailyHealthTipCount = 3;
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
    final dailyCount = await _storageService.loadDailyHealthTipCount();
    if (!mounted) return;
    setState(() {
      _enabled
        ..clear()
        ..addAll(results);
      _dailyHealthTipCount = dailyCount.clamp(0, _maxDailyHealthTips).toInt();
      _loading = false;
    });
  }

  Future<void> _toggle(NotificationKind kind, bool value) async {
    setState(() => _enabled[kind] = value);
    await _storageService.setNotificationKindEnabled(kind.name, value);
    if (kind == NotificationKind.healthTip) {
      await NotificationService.scheduleHealthConditionAdviceNotifications(
        healthConditions: await _storageService.loadHealthConditions(),
        wakeTime: await _storageService.loadSetting('wake_time') ?? '07:00',
        sleepTime: await _storageService.loadSleepTime() ?? '23:00',
      );
    }
  }

  Future<void> _setDailyHealthTipCount(int value) async {
    setState(() => _dailyHealthTipCount = value);
    await _storageService.setDailyHealthTipCount(value);
    await NotificationService.scheduleHealthConditionAdviceNotifications(
      healthConditions: await _storageService.loadHealthConditions(),
      wakeTime: await _storageService.loadSetting('wake_time') ?? '07:00',
      sleepTime: await _storageService.loadSleepTime() ?? '23:00',
    );
  }

  String _titleKey(NotificationKind kind) {
    switch (kind) {
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
            for (final kind in _offeredKinds) ...[
              SwitchListTile(
                key: ValueKey('notification_kind_${kind.name}'),
                contentPadding: EdgeInsets.zero,
                title: Text(context.t(_titleKey(kind))),
                value: _enabled[kind] ?? true,
                onChanged: (value) => _toggle(kind, value),
              ),
              if (kind == NotificationKind.healthTip &&
                  (_enabled[kind] ?? true))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.t('dailyHealthTipCountLabel'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownButton<int>(
                        key: const ValueKey('daily_health_tip_count'),
                        value: _dailyHealthTipCount,
                        items: [
                          for (var n = 0; n <= _maxDailyHealthTips; n++)
                            DropdownMenuItem(value: n, child: Text('$n')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _setDailyHealthTipCount(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
