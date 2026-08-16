import 'package:flutter/material.dart';

import '../core/app_texts.dart';
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
      case SleepRoutineStep.dailyReport:
        return DailyProgressReportView(
          storageService: _storage,
          onClose: _closeReport,
        );
    }
  }
}
