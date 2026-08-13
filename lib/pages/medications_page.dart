import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../models/medication.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class MedicationsPage extends StatefulWidget {
  const MedicationsPage({super.key});

  @override
  State<MedicationsPage> createState() => _MedicationsPageState();
}

class _MedicationsPageState extends State<MedicationsPage> {
  final StorageService _storageService = StorageService();
  List<Medication> _medications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final medications = await _storageService.loadMedications();
    if (!mounted) return;
    setState(() {
      _medications = medications;
      _loading = false;
    });
  }

  Future<void> _rescheduleReminders() async {
    // A medication reminder now only ever says "take this medication" —
    // condition-specific advice is scheduleHealthConditionAdviceNotifications'
    // job, sent to every user with a tracked condition regardless of
    // whether they also take medication. Still recomputed together here
    // because both read from the same medication list this page just
    // changed, not because one depends on the other's outcome.
    await NotificationService.scheduleMedicationReminders(_medications);
    await NotificationService.scheduleHealthConditionAdviceNotifications(
      healthConditions: await _storageService.loadHealthConditions(),
      wakeTime: await _storageService.loadSetting('wake_time') ?? '07:00',
      sleepTime: await _storageService.loadSleepTime() ?? '23:00',
    );
  }

  Future<void> _addOrEditMedication({Medication? existing}) async {
    final result = await showModalBottomSheet<Medication>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MedicationEditorSheet(existing: existing),
    );
    if (result == null) return;

    await _storageService.saveMedication(result);
    await _load();
    await _rescheduleReminders();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('medicationSavedConfirmation'))),
    );
  }

  Future<void> _deleteMedication(Medication medication) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('medicationDeleteConfirmTitle')),
        content: Text(context.t('medicationDeleteConfirmMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t('no')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.t('yes')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _storageService.deleteMedication(medication.id);
    await _load();
    await _rescheduleReminders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('medicationsPageTitle'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _medications.isEmpty
          ? Center(child: Text(context.t('medicationsEmptyState')))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _medications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final medication = _medications[index];
                return Card(
                  child: ListTile(
                    title: Text(medication.name),
                    subtitle: Text(medication.times.join(', ')),
                    onTap: () => _addOrEditMedication(existing: medication),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteMedication(medication),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditMedication(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MedicationEditorSheet extends StatefulWidget {
  const _MedicationEditorSheet({this.existing});

  final Medication? existing;

  @override
  State<_MedicationEditorSheet> createState() => _MedicationEditorSheetState();
}

class _MedicationEditorSheetState extends State<_MedicationEditorSheet> {
  late final TextEditingController _nameController;
  late List<String> _times;
  late int _timesPerDay;

  /// Read from the survey so the suggested times land inside the user's day
  /// rather than at arbitrary clock positions. Falls back to a common
  /// waking window when the survey hasn't been filled in.
  int _wakeMinutes = 7 * 60;
  int _sleepMinutes = 23 * 60;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _times = List<String>.from(widget.existing?.times ?? const []);
    _timesPerDay = _times.isEmpty ? 1 : _times.length;
    _loadWakingWindow();
    if (_times.isEmpty) {
      _times = _suggestTimes(_timesPerDay);
    }
  }

  Future<void> _loadWakingWindow() async {
    final storage = StorageService();
    final sleep = _parseClock(await storage.loadSleepTime());
    final wake = _parseClock(await storage.loadSetting('wake_time'));
    if (!mounted || (sleep == null && wake == null)) return;
    setState(() {
      _wakeMinutes = wake ?? _wakeMinutes;
      _sleepMinutes = sleep ?? _sleepMinutes;
      // Only re-suggest while the user hasn't started editing, so loading
      // this asynchronously can't overwrite a time they just picked.
      if (widget.existing == null) {
        _times = _suggestTimes(_timesPerDay);
      }
    });
  }

  static int? _parseClock(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return (h.clamp(0, 23) * 60) + m.clamp(0, 59);
  }

  static String _formatMinutes(int minutes) {
    final wrapped = minutes % (24 * 60);
    final h = (wrapped ~/ 60).toString().padLeft(2, '0');
    final m = (wrapped % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Spreads [count] doses across the waking day.
  ///
  /// Insets from both ends so nothing lands the minute the user wakes or as
  /// they're falling asleep, then divides the remainder evenly. These are a
  /// starting point, not a prescription — every one stays editable.
  List<String> _suggestTimes(int count) {
    final awake = _sleepMinutes > _wakeMinutes
        ? _sleepMinutes - _wakeMinutes
        : (_sleepMinutes + 24 * 60) - _wakeMinutes;
    if (count <= 1) {
      return [_formatMinutes(_wakeMinutes + (awake ~/ 4))];
    }
    final inset = awake ~/ 8;
    final usable = awake - (inset * 2);
    final step = usable ~/ (count - 1);
    return List.generate(
      count,
      (i) => _formatMinutes(_wakeMinutes + inset + (step * i)),
    );
  }

  Future<void> _editTime(int index) async {
    final current = _parseClock(_times[index]) ?? (8 * 60);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    setState(() {
      _times[index] =
          '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty || _times.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final now = DateTime.now();
    Navigator.of(context).pop(
      Medication(
        id: widget.existing?.id ?? now.millisecondsSinceEpoch.toString(),
        name: name,
        times: _times,
        createdAt: widget.existing?.createdAt ?? now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: 16,
        end: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: context.t('medicationNameHint'),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          // Asked before the times, because how often someone takes something
          // is the thing they actually know — the clock positions follow from
          // it. Previously they had to add each time one at a time and the
          // count was only ever implied by how many they'd added.
          DropdownButtonFormField<int>(
            isExpanded: true,
            key: const ValueKey('medication_times_per_day'),
            initialValue: _timesPerDay,
            decoration: InputDecoration(
              labelText: context.t('medicationTimesPerDay'),
            ),
            items: [
              for (var count = 1; count <= 6; count++)
                DropdownMenuItem(value: count, child: Text('$count')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _timesPerDay = value;
                _times = _suggestTimes(value);
              });
            },
          ),
          const SizedBox(height: 6),
          Text(
            context.t('medicationTimesPerDayHint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _times.length; i++)
            ListTile(
              key: ValueKey('medication_time_$i'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.alarm),
              title: Text(_times[i]),
              subtitle: Text(
                context
                    .t('medicationTimeSlotLabel')
                    .replaceAll('{index}', '${i + 1}'),
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editTime(i),
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(context.t('save'))),
        ],
      ),
    );
  }
}
