import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../services/sleep_intelligence_service.dart';
import '../services/sleep_routine_flow_engine.dart';
import '../services/storage_service.dart';
import '../services/task_assignment_service.dart';
import '../widgets/daily_progress_report_view.dart';
import 'breath_test_page.dart';
import 'cough_test_page.dart';

/// The pre-sleep mandatory routine: breath test, cough test, then the daily
/// progress report. The report already displays today's logged cigarette
/// count, so the old survey-average-versus-hour-table question is not shown.
class SleepRoutinePage extends StatefulWidget {
  final String canonicalTitle;
  final String name;
  final String packsPerDay;
  final StorageService? storageService;
  final TaskAssignmentService? taskAssignmentService;
  final SleepRoutineFlowEngine? flowEngine;

  const SleepRoutinePage({
    super.key,
    required this.canonicalTitle,
    this.name = '',
    this.packsPerDay = '1 paketten az',
    this.storageService,
    this.taskAssignmentService,
    this.flowEngine,
  });

  @override
  State<SleepRoutinePage> createState() => _SleepRoutinePageState();
}

class _SleepRoutinePageState extends State<SleepRoutinePage> {
  late final StorageService _storage;
  late final TaskAssignmentService _taskAssignmentService;
  late final SleepRoutineFlowEngine _flowEngine;

  List<SleepRoutineStep>? _steps;
  int _currentStepIndex = 0;
  TimeOfDay? _tonightSleepTime;
  TimeOfDay? _nextDayWakeTime;

  @override
  void initState() {
    super.initState();
    _storage = widget.storageService ?? StorageService();
    _taskAssignmentService =
        widget.taskAssignmentService ?? TaskAssignmentService(_storage);
    _flowEngine = widget.flowEngine ?? const SleepRoutineFlowEngine();
    _loadSteps();
  }

  Future<void> _loadSteps() async {
    if (!mounted) return;
    setState(() {
      _steps = _flowEngine.buildSteps();
    });
  }

  void _advanceStep() {
    final steps = _steps;
    if (steps == null || _currentStepIndex >= steps.length - 1) return;
    setState(() => _currentStepIndex += 1);
  }

  Future<void> _saveTonightSleepTime() async {
    final selected = _tonightSleepTime;
    if (selected == null) return;
    final formatted = '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    await _storage.saveSleepTime(formatted);
    await SleepIntelligenceService(storageService: _storage)
        .refreshScheduleIfEnabled();
    if (!mounted) return;
    _advanceStep();
  }

  Future<void> _pickTonightSleepTime() async {
    final stored = await _storage.loadSleepTime();
    if (!mounted || !context.mounted) return;
    final selected = await showTimePicker(
      context: context,
      initialTime: _tonightSleepTime ?? _parseTime(stored) ?? const TimeOfDay(hour: 23, minute: 0),
      helpText: context.t('sleepTime'),
    );
    if (selected != null && mounted) {
      setState(() => _tonightSleepTime = selected);
    }
  }

  TimeOfDay? _parseTime(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _saveNextDayWakeTime() async {
    final selected = _nextDayWakeTime;
    if (selected == null) return;
    final nextDay = DateTime.now().add(const Duration(days: 1));
    await _storage.saveWakeTimeForDate(date: nextDay, wakeTime: selected);
    await SleepIntelligenceService(storageService: _storage)
        .scheduleMorningReportForDate(nextDay);
    if (!mounted) return;
    _advanceStep();
  }

  Future<void> _pickNextDayWakeTime() async {
    final stored = await _storage.loadWakeTimeForDate(
      DateTime.now().add(const Duration(days: 1)),
    );
    if (!mounted) return;
    final selected = await showTimePicker(
      context: context,
      initialTime: _nextDayWakeTime ?? stored ?? const TimeOfDay(hour: 7, minute: 0),
      helpText: context.t('wakeTime'),
    );
    if (selected != null && mounted) {
      setState(() => _nextDayWakeTime = selected);
    }
  }

  Widget _buildTonightSleepTimeStep() {
    final selected = _tonightSleepTime;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t('sleepRoutineTonightTitle'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(context.t('sleepRoutineTonightBody'), textAlign: TextAlign.center),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _pickTonightSleepTime,
            icon: const Icon(Icons.nightlight_outlined),
            label: Text(selected == null ? context.t('sleepRoutineTonightTitle') : selected.format(context)),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: selected == null ? null : _saveTonightSleepTime,
            child: Text(context.t('continue')),
          ),
        ],
      ),
    );
  }

  Widget _buildNextDayWakeTimeStep() {
    final selected = _nextDayWakeTime;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t('wakeTime'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            context.t('sleepRoutineIntro'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _pickNextDayWakeTime,
            icon: const Icon(Icons.schedule),
            label: Text(
              selected == null ? context.t('wakeTime') : selected.format(context),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: selected == null ? null : _saveNextDayWakeTime,
            child: Text(context.t('continue')),
          ),
        ],
      ),
    );
  }

  Future<void> _closeReport() async {
    await _taskAssignmentService.completeSleepRoutine(widget.canonicalTitle);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.t('sleepRoutineTitle')),
          automaticallyImplyLeading: false,
        ),
        body: steps == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LinearProgressIndicator(
                            value: (_currentStepIndex + 1) / steps.length,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.t('sleepRoutineStepIndicator')
                                .replaceAll(
                                  '{current}',
                                  '${_currentStepIndex + 1}',
                                )
                                .replaceAll('{total}', '${steps.length}'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _buildStep(steps[_currentStepIndex])),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStep(SleepRoutineStep step) {
    switch (step) {
      case SleepRoutineStep.breathTest:
        return BreathTestPage(
          name: widget.name,
          packsPerDay: widget.packsPerDay,
          onCompleted: _advanceStep,
        );
      case SleepRoutineStep.coughTest:
        return CoughTestPage(onFinishRequested: _advanceStep);
      case SleepRoutineStep.tonightSleepTime:
        return _buildTonightSleepTimeStep();
      case SleepRoutineStep.nextDayWakeTime:
        return _buildNextDayWakeTimeStep();
      case SleepRoutineStep.dailyReport:
        return DailyProgressReportView(
          storageService: _storage,
          onClose: _closeReport,
        );
    }
  }
}
