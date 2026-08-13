import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../core/app_theme.dart';
import '../models/smoking_count_discrepancy.dart';
import '../services/sleep_routine_flow_engine.dart';
import '../services/storage_service.dart';
import '../services/task_assignment_service.dart';
import '../widgets/daily_progress_report_view.dart';
import 'breath_test_page.dart';
import 'cough_test_page.dart';

/// The pre-sleep mandatory routine — breath test, cough test, an optional
/// smoking-count discrepancy question, then a daily progress report — shown
/// once accepting the `SLEEP_ROUTINE` task from [MandatoryTaskPage].
///
/// [PopScope(canPop: false)] the same way MandatoryTaskPage is: this is a
/// commitment already accepted, not a screen to back out of. Steps run in a
/// fixed order (see [SleepRoutineFlowEngine]) and never go backwards.
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
  SmokingCountDiscrepancy? _discrepancy;

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
    final discrepancy = await _storage.evaluateTodaySmokingDiscrepancy();
    if (!mounted) return;
    setState(() {
      _discrepancy = discrepancy;
      _steps = _flowEngine.buildSteps(
        hasDiscrepancy: discrepancy.hasDiscrepancy,
      );
    });
  }

  void _advanceStep() {
    final steps = _steps;
    if (steps == null) return;
    if (_currentStepIndex >= steps.length - 1) {
      return;
    }
    setState(() {
      _currentStepIndex += 1;
    });
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
                            context
                                .t('sleepRoutineStepIndicator')
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
      case SleepRoutineStep.smokingDiscrepancyQuestion:
        return _SmokingDiscrepancyStep(
          discrepancy: _discrepancy,
          storage: _storage,
          onDone: _advanceStep,
        );
      case SleepRoutineStep.dailyReport:
        return DailyProgressReportView(
          storageService: _storage,
          onClose: _closeReport,
        );
    }
  }
}

/// "Bugün beklenenden N sigara az logladık, unuttukların var mı?" — lets the
/// user pick which of today's waking hours they forgot to log, or confirm
/// their log is already correct. Either choice advances the routine.
class _SmokingDiscrepancyStep extends StatefulWidget {
  final SmokingCountDiscrepancy? discrepancy;
  final StorageService storage;
  final VoidCallback onDone;

  const _SmokingDiscrepancyStep({
    required this.discrepancy,
    required this.storage,
    required this.onDone,
  });

  @override
  State<_SmokingDiscrepancyStep> createState() =>
      _SmokingDiscrepancyStepState();
}

class _SmokingDiscrepancyStepState extends State<_SmokingDiscrepancyStep> {
  final Set<int> _selectedHours = {};
  bool _saving = false;

  int get _gap => widget.discrepancy?.gap ?? 0;

  Future<void> _confirmNoneMissing() async {
    widget.onDone();
  }

  Future<void> _saveRecalledHours() async {
    if (_saving) return;
    setState(() => _saving = true);
    await widget.storage.logRecalledSmokingHours(
      day: DateTime.now(),
      hours: _selectedHours.toList(),
    );
    if (!mounted) return;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final hours = List<int>.generate(24, (h) => h);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text(
              context.t('sleepRoutineDiscrepancyQuestionTitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              context
                  .t('sleepRoutineDiscrepancyQuestionBody')
                  .replaceAll('{count}', '$_gap'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final hour in hours)
                      ChoiceChip(
                        label: Text('${hour.toString().padLeft(2, '0')}:00'),
                        selected: _selectedHours.contains(hour),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedHours.add(hour);
                            } else {
                              _selectedHours.remove(hour);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving || _selectedHours.isEmpty
                    ? null
                    : _saveRecalledHours,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                ),
                child: Text(context.t('sleepRoutineDiscrepancyConfirmButton')),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _saving ? null : _confirmNoneMissing,
                child: Text(context.t('sleepRoutineDiscrepancyNoneButton')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
