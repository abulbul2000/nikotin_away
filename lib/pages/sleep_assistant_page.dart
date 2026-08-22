import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../services/sleep_intelligence_service.dart';
import '../services/storage_service.dart';

/// A simple, user-controlled sleep assistant surface. The assistant never
/// changes a persistent wake plan without an explicit save action.
class SleepAssistantPage extends StatefulWidget {
  const SleepAssistantPage({super.key});

  @override
  State<SleepAssistantPage> createState() => _SleepAssistantPageState();
}

class _SleepAssistantPageState extends State<SleepAssistantPage> {
  final StorageService _storage = StorageService();
  final SleepIntelligenceService _sleep = SleepIntelligenceService();

  bool _enabled = false;
  bool _loading = true;
  TimeOfDay? _tomorrowWake;
  DateTime? _vacationUntil;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _sleep.isEnabled();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final wake = await _storage.loadWakeTimeForDate(tomorrow);
    final vacationRaw = await _storage.loadSetting('sleep_vacation_until');
    final vacation = vacationRaw == null ? null : DateTime.tryParse(vacationRaw);
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _tomorrowWake = wake;
      _vacationUntil = vacation;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      await _sleep.enable();
    } else {
      await _sleep.disable();
    }
    if (!mounted) return;
    setState(() => _enabled = value);
  }

  Future<void> _pickTomorrowWake() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _tomorrowWake ?? const TimeOfDay(hour: 7, minute: 0),
      helpText: context.t('wakeTime'),
    );
    if (selected == null) return;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await _storage.saveWakeTimeForDate(date: tomorrow, wakeTime: selected);
    await _storage.saveSetting('wake_time_last_user_confirmed', DateTime.now().toIso8601String());
    await _sleep.scheduleMorningReportForDate(tomorrow);
    if (!mounted) return;
    setState(() => _tomorrowWake = selected);
  }

  Future<void> _pickVacationEnd() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
      initialDate: _vacationUntil ?? now.add(const Duration(days: 7)),
      helpText: context.t('sleepIntelligenceTitle'),
    );
    if (selected == null) return;
    final until = DateTime(selected.year, selected.month, selected.day, 23, 59, 59);
    await _storage.saveSetting('sleep_vacation_until', until.toIso8601String());
    if (!mounted) return;
    setState(() => _vacationUntil = until);
  }

  Future<void> _clearVacation() async {
    await _storage.saveSetting('sleep_vacation_until', '');
    if (!mounted) return;
    setState(() => _vacationUntil = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final colors = Theme.of(context).colorScheme;
    final tomorrowLabel = _tomorrowWake?.format(context) ?? context.t('wakeTime');
    final vacationActive = _vacationUntil != null && _vacationUntil!.isAfter(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: Text(context.t('sleepIntelligenceTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: SwitchListTile.adaptive(
              value: _enabled,
              onChanged: _toggle,
              title: Text(context.t('sleepIntelligenceTitle')),
              subtitle: Text(context.t('sleepIntelligenceDescription')),
              secondary: Icon(Icons.alarm_outlined, color: colors.primary),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.t('wakeTime'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(context.t('sleepIntelligencePurpose')),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _pickTomorrowWake,
                    icon: const Icon(Icons.schedule),
                    label: Text(tomorrowLabel),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.t('sleepIntelligenceTitle'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(context.t('sleepIntelligenceDescription')),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _pickVacationEnd,
                    icon: const Icon(Icons.beach_access_outlined),
                    label: Text(vacationActive ? _vacationUntil!.toLocal().toString().split(' ').first : context.t('save')),
                  ),
                  if (vacationActive)
                    TextButton.icon(
                      onPressed: _clearVacation,
                      icon: const Icon(Icons.clear),
                      label: Text(context.t('cancel')),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

