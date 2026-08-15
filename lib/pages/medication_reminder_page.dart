import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../services/notification_service.dart';

class MedicationReminderPage extends StatefulWidget {
  final String medicationId;
  final String medicationName;

  const MedicationReminderPage({
    super.key,
    required this.medicationId,
    required this.medicationName,
  });

  @override
  State<MedicationReminderPage> createState() => _MedicationReminderPageState();
}

class _MedicationReminderPageState extends State<MedicationReminderPage> {
  bool _busy = false;

  Future<void> _respond(String actionId) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
    });

    await NotificationService.handleMedicationReminderAction(
      actionId: actionId,
      medicationId: widget.medicationId,
      medicationName: widget.medicationName,
    );

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('medicationReminderTitle'))),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.medication_outlined, size: 72),
                const SizedBox(height: 24),
                Text(
                  widget.medicationName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  context.t('medicationReminderTitle'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _respond('medication_taken'),
                    child: Text(context.t('taskActionDoneLabel')),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _respond('medication_postpone'),
                    child: Text(context.t('taskActionNotNowLabel')),
                  ),
                ),
                if (_busy) ...[
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
