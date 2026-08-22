import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../services/sleep_intelligence_service.dart';
import '../services/storage_service.dart';

/// User-controlled sleep schedule and wake-alarm settings.
class SleepAssistantPage extends StatefulWidget {
  const SleepAssistantPage({super.key});

  @override
  State<SleepAssistantPage> createState() => _SleepAssistantPageState();
}

class _SleepAssistantPageState extends State<SleepAssistantPage> {
  final StorageService _storage = StorageService();
  final SleepIntelligenceService _sleep = SleepIntelligenceService();

  static const List<String> _dayKeys = <String>[
    'dayMonShort',
    'dayTueShort',
    'dayWedShort',
    'dayThuShort',
    'dayFriShort',
    'daySatShort',
    'daySunShort',
  ];

  bool _enabled = false;
  bool _loading = true;
  bool _wakeAlarmEnabled = false;
  String _scheduleMode = 'daily';
  int _selectedDay = 1;
  DateTime? _vacationUntil;
  final Map<int, TimeOfDay> _sleepTimes = <int, TimeOfDay>{};
  final Map<int, TimeOfDay> _wakeTimes = <int, TimeOfDay>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _sleep.isEnabled();
    final mode = await _storage.loadSleepScheduleMode();
    final alarmEnabled = await _storage.loadWakeAlarmEnabled();
    final sleepFallback = _parseTime(await _storage.loadSleepTime() ?? '23:00') ??
        const TimeOfDay(hour: 23, minute: 0);
    final wakeFallback = _parseTime(await _storage.loadSetting('wake_time') ?? '07:00') ??
        const TimeOfDay(hour: 7, minute: 0);
    final loadedSleep = <int, TimeOfDay>{};
    final loadedWake = <int, TimeOfDay>{};
    for (var day = 1; day <= 7; day++) {
      loadedSleep[day] = await _storage.loadSleepScheduleTime(
            weekday: day,
            wake: false,
          ) ??
          sleepFallback;
      loadedWake[day] = await _storage.loadSleepScheduleTime(
            weekday: day,
            wake: true,
          ) ??
          wakeFallback;
    }
    final vacationRaw = await _storage.loadSetting('sleep_vacation_until');
    final vacation = vacationRaw == null ? null : DateTime.tryParse(vacationRaw);
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _scheduleMode = mode;
      _wakeAlarmEnabled = alarmEnabled;
      _sleepTimes.addAll(loadedSleep);
      _wakeTimes.addAll(loadedWake);
      _vacationUntil = vacation;
      _loading = false;
    });
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  TimeOfDay? _parseTime(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
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

  Future<void> _pickTime({required bool wake}) async {
    final current = (wake ? _wakeTimes : _sleepTimes)[_selectedDay] ??
        (wake ? const TimeOfDay(hour: 7, minute: 0) : const TimeOfDay(hour: 23, minute: 0));
    final selected = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: context.t(wake ? 'wakeTime' : 'sleepTime'),
    );
    if (selected == null) return;
    setState(() {
      (wake ? _wakeTimes : _sleepTimes)[_selectedDay] = selected;
    });
  }

  Future<void> _saveSchedule() async {
    final sourceSleep = _sleepTimes[_selectedDay] ?? const TimeOfDay(hour: 23, minute: 0);
    final sourceWake = _wakeTimes[_selectedDay] ?? const TimeOfDay(hour: 7, minute: 0);
    final days = _scheduleMode == 'daily' ? List<int>.generate(7, (i) => i + 1) : <int>[_selectedDay];
    for (final day in days) {
      await _storage.saveSleepScheduleTime(weekday: day, wake: false, time: sourceSleep);
      await _storage.saveSleepScheduleTime(weekday: day, wake: true, time: sourceWake);
    }
    await _storage.saveSleepScheduleMode(_scheduleMode);
    await _storage.saveSleepTime(_formatTime(_sleepTimes[1] ?? sourceSleep));
    await _storage.saveSetting('wake_time', _formatTime(_wakeTimes[1] ?? sourceWake));
    await _sleep.refreshScheduleIfEnabled();
    await _sleep.scheduleConfiguredWakeAlarms();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('save'))),
    );
  }

  Future<void> _setWakeAlarm(bool value) async {
    await _storage.saveWakeAlarmEnabled(value);
    if (value) {
      await _sleep.scheduleConfiguredWakeAlarms();
    } else {
      await _sleep.cancelConfiguredWakeAlarms();
    }
    if (!mounted) return;
    setState(() => _wakeAlarmEnabled = value);
  }

  Future<void> _pickVacationEnd() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
      initialDate: _vacationUntil ?? now.add(const Duration(days: 7)),
      helpText: context.t('sleepScheduleTitle'),
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
    final sleep = _sleepTimes[_selectedDay] ?? const TimeOfDay(hour: 23, minute: 0);
    final wake = _wakeTimes[_selectedDay] ?? const TimeOfDay(hour: 7, minute: 0);
    final vacationActive = _vacationUntil != null && _vacationUntil!.isAfter(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: Text(context.t('sleepScheduleTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: SwitchListTile.adaptive(
              value: _enabled,
              onChanged: _toggle,
              title: Text(context.t('sleepScheduleTitle')),
              subtitle: Text(context.t('sleepScheduleDescription')),
              secondary: Icon(Icons.bedtime_outlined, color: colors.primary),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.t('sleepScheduleTitle'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(context.t('sleepScheduleDescription')),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'daily', label: Text(context.t('scheduleDaily'))),
                      ButtonSegment(value: 'weekly', label: Text(context.t('scheduleByDay'))),
                    ],
                    selected: {_scheduleMode},
                    onSelectionChanged: (value) => setState(() => _scheduleMode = value.first),
                  ),
                  const SizedBox(height: 12),
                  if (_scheduleMode == 'weekly')
                    DropdownButtonFormField<int>(
                      initialValue: _selectedDay,
                      decoration: InputDecoration(labelText: context.t('days')),
                      items: [
                        for (var day = 1; day <= 7; day++)
                          DropdownMenuItem(value: day, child: Text(context.t(_dayKeys[day - 1]))),
                      ],
                      onChanged: (value) => setState(() => _selectedDay = value ?? 1),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _pickTime(wake: false),
                    icon: const Icon(Icons.nightlight_outlined),
                    label: Text('${context.t('sleepTime')}: ${sleep.format(context)}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickTime(wake: true),
                    icon: const Icon(Icons.wb_sunny_outlined),
                    label: Text('${context.t('wakeTime')}: ${wake.format(context)}'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _wakeAlarmEnabled,
                    onChanged: _setWakeAlarm,
                    title: Text(context.t('wakeAlarmEnabledTitle')),
                    subtitle: Text(context.t('wakeAlarmEnabledDescription')),
                    secondary: const Icon(Icons.alarm_outlined),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _saveSchedule,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(context.t('save')),
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
                  Text(context.t('sleepScheduleTitle'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(context.t('sleepScheduleDescription')),
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
