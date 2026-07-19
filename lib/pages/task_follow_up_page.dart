import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../models/adaptive_task_models.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class TaskFollowUpPage extends StatefulWidget {
  const TaskFollowUpPage({super.key});

  @override
  State<TaskFollowUpPage> createState() => _TaskFollowUpPageState();
}

class _TaskFollowUpPageState extends State<TaskFollowUpPage> {
  final StorageService _storageService = StorageService();
  bool _loading = true;
  List<Map<String, dynamic>> _pending = const [];

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    final pending = await _storageService.loadPendingTaskFollowUps();
    if (!mounted) {
      return;
    }
    setState(() {
      _pending = pending;
      _loading = false;
    });
  }

  Future<void> _saveOutcome({
    required String taskTitle,
    required String outcome,
    DateTime? scheduledAt,
  }) async {
    final success = outcome == AdaptiveTaskOutcome.success;
    final smoked = outcome == AdaptiveTaskOutcome.smoked;

    if (smoked) {
      await _storageService.saveProtocolViolation(
        type: 'followup_failed',
        severity: 'medium',
        source: 'app_flow',
        taskTitle: taskTitle,
        details: 'Task follow-up marked as unsuccessful.',
      );
    }

    final plannedMinutes = _extractPlannedMinutes(taskTitle);
    await _storageService.recordAdaptiveTaskOutcome(
      taskTitle: taskTitle,
      outcome: outcome,
      plannedDurationMinutes: plannedMinutes,
      scheduledAt: scheduledAt,
      respondedAt: DateTime.now(),
    );

    await _storageService.saveTaskResult(
      taskTitle: taskTitle,
      taskResult: success ? 'willpower_success' : 'willpower_weakness',
      completedAt: DateTime.now(),
    );
    await _storageService.resolveTaskFollowUpByTitle(taskTitle);
    await _loadPending();
  }

  Future<void> _deferAgain(String taskTitle) async {
    final delay = await _storageService.resolveAdaptivePostponeDelay();
    final nextTime = DateTime.now().add(delay);

    final plannedMinutes = _extractPlannedMinutes(taskTitle);
    await _storageService.recordAdaptiveTaskOutcome(
      taskTitle: taskTitle,
      outcome: AdaptiveTaskOutcome.deferred,
      plannedDurationMinutes: plannedMinutes,
      scheduledAt: DateTime.now(),
      respondedAt: DateTime.now(),
    );

    await _storageService.saveProtocolViolation(
      type: 'followup_deferred',
      severity: 'low',
      source: 'app_flow',
      taskTitle: taskTitle,
      details: 'User deferred follow-up from dedicated follow-up screen.',
    );
    await _storageService.saveTaskFollowUp(taskTitle: taskTitle, scheduledAt: nextTime);
    await NotificationService.scheduleTaskFollowUpReminder(
      taskTitle: taskTitle,
      delay: delay,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('taskDeferredTenMinutes'))),
    );
    await _loadPending();
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  int _extractPlannedMinutes(String taskTitle) {
    final adaptiveCanonical = RegExp(
      r'^ADAPTIVE_NO_SMOKE:(\d+)$',
      caseSensitive: false,
    ).firstMatch(taskTitle.trim());
    if (adaptiveCanonical != null) {
      final minutes = int.tryParse(adaptiveCanonical.group(1) ?? '');
      if (minutes != null && minutes > 0) {
        return minutes;
      }
    }

    final minuteMatch = RegExp(
      r'(\d+)\s*(dakika|minute|minutes|min)',
      caseSensitive: false,
    ).firstMatch(taskTitle);
    if (minuteMatch != null) {
      final minutes = int.tryParse(minuteMatch.group(1) ?? '');
      if (minutes != null && minutes > 0) {
        return minutes;
      }
    }
    return 15;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('taskFollowUpTitle')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pending.isEmpty
              ? Center(
                  child: Text(context.t('taskFollowUpEmpty')),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pending.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final row = _pending[index];
                    final taskTitle = row['taskTitle'] as String;
                    final scheduledAt = row['scheduledAt'] as DateTime;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppTexts.localizeCanonicalText(context, taskTitle),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('${context.t('taskFollowUpScheduledAt')}: ${_formatDateTime(scheduledAt)}'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _saveOutcome(
                                    taskTitle: taskTitle,
                                    outcome: AdaptiveTaskOutcome.success,
                                    scheduledAt: scheduledAt,
                                  ),
                                  child: const Text('Basardim'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _saveOutcome(
                                    taskTitle: taskTitle,
                                    outcome: AdaptiveTaskOutcome.smoked,
                                    scheduledAt: scheduledAt,
                                  ),
                                  child: const Text('Sigara ictim'),
                                ),
                                TextButton(
                                  onPressed: () => _deferAgain(taskTitle),
                                  child: const Text('Ertele'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
