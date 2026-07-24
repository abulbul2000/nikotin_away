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
    await NotificationService.scheduleMedicationReminders(_medications);
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
  State<_MedicationEditorSheet> createState() =>
      _MedicationEditorSheetState();
}

class _MedicationEditorSheetState extends State<_MedicationEditorSheet> {
  late final TextEditingController _nameController;
  late final List<String> _times;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _times = List<String>.from(widget.existing?.times ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (!_times.contains(formatted)) {
        _times.add(formatted);
        _times.sort();
      }
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
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final time in _times)
                Chip(
                  label: Text(time),
                  onDeleted: () => setState(() => _times.remove(time)),
                ),
              ActionChip(
                avatar: const Icon(Icons.add_alarm, size: 18),
                label: Text(context.t('addMedicationTimeButton')),
                onPressed: _addTime,
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(context.t('save'))),
        ],
      ),
    );
  }
}
