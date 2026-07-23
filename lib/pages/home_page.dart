import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../core/app_theme.dart';
import '../models/adaptive_task_models.dart';
import '../models/mentor_message.dart';
import '../models/survey_record.dart';
import '../models/user_profile_snapshot.dart';
import '../pages/breath_test_page.dart';
import '../pages/craving_sos_page.dart';
import '../pages/daily_checkin_page.dart';
import '../pages/health_metrics_page.dart';
import '../pages/mandatory_task_page.dart';
import '../pages/personal_progress_page.dart';
import '../pages/protocol_violations_page.dart';
import '../pages/reports_page.dart';
import '../pages/settings_page.dart';
import '../pages/survey_history_page.dart';
import '../pages/task_follow_up_page.dart';
import '../pages/weekly_survey_page.dart';
import '../services/device_permission_service.dart';
import '../services/discipline_protocol_service.dart';
import '../services/fake_call_barrier_service.dart';
import '../services/location_intelligence_service.dart';
import '../services/step_tracking_service.dart';
import '../services/notification_service.dart';
import '../services/protocol_violation_service.dart';
import '../services/storage_service.dart';
import '../widgets/no_smoke_logo.dart';

class HomePage extends StatefulWidget {
  final String name;
  final int riskScore;
  final String riskLevel;
  final bool autoCompleteRegistrationOnLoad;

  const HomePage({
    super.key,
    required this.name,
    required this.riskScore,
    required this.riskLevel,
    this.autoCompleteRegistrationOnLoad = false,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final StorageService _storageService = StorageService();
  final StepTrackingService _stepTrackingService = StepTrackingService();
  final ProtocolViolationService _protocolViolationService =
      ProtocolViolationService();
  final DisciplineProtocolService _disciplineProtocolService =
      DisciplineProtocolService();
  final FakeCallBarrierService _fakeCallBarrierService =
      FakeCallBarrierService();
  final Map<String, String> _taskStates = {};
  final Map<String, Timer> _taskFollowUpTimers = {};
  final Map<String, Timer> _durationBarrierTimers = {};
  final Map<String, DateTime> _taskStartedAt = {};
  final Map<String, DateTime> _durationBarrierEndsAt = {};
  final Set<String> _notifiedTaskTitles = <String>{};
  MentorMessage? _latestMentorMessage;
  StreamSubscription<Map<String, String>>? _taskActionSubscription;
  Timer? _durationBarrierTicker;
  Timer? _mandatoryGateCallRetryTimer;
  List<Map<String, dynamic>> _pendingFollowUps = const [];
  bool _mandatoryTaskShown = false;
  bool _weeklySurveyMandatoryShown = false;
  bool _weeklySurveyPromptShownSession = false;
  bool _dailyBreathMandatoryShownSession = false;
  bool _registrationCompleted = false;
  bool _isCompletingRegistration = false;
  String _lastSurveyDateText = '...';
  String _lastBreathText = '...';
  String _dailyBreathStatus = '...';
  int _latestExhaleSeconds = 0;
  int _latestInhaleSeconds = 0;
  String _breathTrendText = '...';
  // 'improving'/'worsening'/'stable' — see BehaviorDashboard.breathTrendLast3.
  // Drives the fake-call barrier's daily frequency/duration and the
  // mentor's daily message, not shown to the user directly.
  String _breathTrendRecent = 'stable';
  String _weeklyImprovementText = '...';
  String _monthlyImprovementText = '...';
  String _breathPreviousReportText = '...';
  String _breathAverageReportText = '...';
  String _progressSummaryText = '...';
  String _predictedRiskWindow = '...';
  String _predictedTrigger = '...';
  int _predictionConfidence = 0;
  int _adaptiveRiskScore = 0;
  int _weeklyRiskTarget = 0;
  int _planCurrentDay = 1;
  int _planTargetDays = 180;
  int _planDaysRemaining = 179;
  String _planCadenceLevel = 'one_day';
  List<String> _riskyTriggers = const [];
  List<String> _riskyHours = const [];
  List<String> _todaysTasks = const [];
  List<AdaptiveTaskPlanItem> _adaptivePlanItems = const [];
  List<String> _coachCommands = const [];
  List<String> _durationBarrierCommands = const [];
  Map<String, double> _commandSuccessScores = const {};
  Map<String, double> _commandCategoryScores = const {};
  String _commandMixMode = 'balanced';
  int _weeklySurveyRiskScore = 40;
  String _weeklySurveyRiskLevel = 'medium';
  List<String> _weeklyTopRiskDrivers = const [];
  List<String> _riskExplanation = const [];
  Map<String, double> _learnedWeights = const {};
  String _consecutiveSmokingLatestText = '...';
  String _consecutiveSmokingPreviousText = '...';
  String _consecutiveSmokingTrendText = '...';
  String _consecutiveSmokingStatusText = '...';
  int _successfulTaskCount = 0;
  int _failedTaskCount = 0;
  int _recentSuccessCount = 0;
  int _recentFailureCount = 0;
  String _nextTaskNotificationText = '...';
  String _notificationContextReasonText = '...';
  String _durationBarrierPreference = 'neutral';
  String _durationBarrierFrequencyPreference = 'orta';
  bool _durationBarrierEnabled = true;
  int _durationBarrierHistoryCount = 0;
  int _lastRespiratoryBurden = 25;
  String _lastRespiratoryState = 'stable';
  double _weeklyAverage = 0;
  double _monthlyAverage = 0;
  double _dailyAverage = 0;
  int _smokeFreeDays = 0; // Kaç gündür sigara içmedi

  @override
  void initState() {
    super.initState();
    _taskActionSubscription = NotificationService.taskActionStream.listen(
      _handleTaskNotificationAction,
    );
    _loadHomeMetrics();
    unawaited(LocationIntelligenceService().sampleCurrentLocationIfDue());
    unawaited(_stepTrackingService.sampleCurrentStepsIfDue());
    unawaited(_stepTrackingService.ensureDailyProbeScheduled());
  }

  @override
  void dispose() {
    _taskActionSubscription?.cancel();
    for (final timer in _taskFollowUpTimers.values) {
      timer.cancel();
    }
    for (final timer in _durationBarrierTimers.values) {
      timer.cancel();
    }
    _durationBarrierTicker?.cancel();
    _mandatoryGateCallRetryTimer?.cancel();
    super.dispose();
  }

  void _scheduleLocalFollowUp(String taskTitle, DateTime scheduledAt) {
    final remaining = scheduledAt.difference(DateTime.now());
    final delay = remaining.isNegative ? Duration.zero : remaining;
    _taskFollowUpTimers[taskTitle]?.cancel();
    _taskFollowUpTimers[taskTitle] = Timer(delay, () {
      if (!mounted) {
        return;
      }
      _askTaskOutcome(taskTitle);
    });
  }

  void _scheduleLocalDurationBarrierFollowUp(
    String taskTitle,
    DateTime scheduledAt,
  ) {
    final remaining = scheduledAt.difference(DateTime.now());
    final delay = remaining.isNegative ? Duration.zero : remaining;
    _durationBarrierTimers[taskTitle]?.cancel();
    _durationBarrierTimers[taskTitle] = Timer(delay, () {
      if (!mounted) {
        return;
      }
      _completeDurationBarrier(taskTitle);
    });
    _ensureDurationBarrierTicker();
  }

  void _ensureDurationBarrierTicker() {
    final hasActiveBarrier = _durationBarrierEndsAt.values.any(
      (endAt) => endAt.isAfter(DateTime.now()),
    );
    if (!hasActiveBarrier) {
      _durationBarrierTicker?.cancel();
      _durationBarrierTicker = null;
      return;
    }

    _durationBarrierTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      final stillActive = _durationBarrierEndsAt.values.any(
        (endAt) => endAt.isAfter(DateTime.now()),
      );
      if (!stillActive) {
        _durationBarrierTicker?.cancel();
        _durationBarrierTicker = null;
      }
    });
  }

  bool _isDurationBarrierTask(String taskTitle) {
    final normalized = taskTitle.toLowerCase();
    return normalized.contains('sure bariyeri') ||
        normalized.contains('sigara içmeme süresi') ||
        normalized.contains('sigara icmeme suresi') ||
        taskTitle.contains('SURE-BARIYERI') ||
        taskTitle.contains('Sigara içmeme süresi') ||
        taskTitle.contains('SIGARA_ICMEME_SURESI');
  }

  List<Map<String, dynamic>> _activeDurationBarriers() {
    final now = DateTime.now();
    return _pendingFollowUps.where((row) {
      final title = row['taskTitle']?.toString() ?? '';
      final scheduledAt = row['scheduledAt'];
      return _isDurationBarrierTask(title) &&
          scheduledAt is DateTime &&
          scheduledAt.isAfter(now);
    }).toList()..sort(
      (a, b) => (a['scheduledAt'] as DateTime).compareTo(
        b['scheduledAt'] as DateTime,
      ),
    );
  }

  String _formatRemainingDuration(Duration duration) {
    final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final totalMinutes = (totalSeconds / 60).ceil();
    if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      final remainingMinutes = totalMinutes % 60;
      if (remainingMinutes == 0) {
        return '$hours saat';
      }
      return '$hours saat $remainingMinutes dakika';
    }
    return '$totalMinutes dakika';
  }

  Future<void> _restorePendingFollowUps() async {
    final pending = await _storageService.loadPendingTaskFollowUps();
    if (!mounted) {
      return;
    }

    setState(() {
      _pendingFollowUps = pending;
    });

    for (final row in pending) {
      final taskTitle = row['taskTitle'] as String;
      final scheduledAt = row['scheduledAt'] as DateTime;
      if (_isDurationBarrierTask(taskTitle)) {
        _durationBarrierEndsAt[taskTitle] = scheduledAt;
        _scheduleLocalDurationBarrierFollowUp(taskTitle, scheduledAt);
        _taskStates[taskTitle] = 'deferred';
      } else {
        _scheduleLocalFollowUp(taskTitle, scheduledAt);
        _taskStates[taskTitle] = 'deferred';
      }
    }
    _ensureDurationBarrierTicker();
  }

  String _calculateImprovementLabel(double current, double baseline) {
    if (current > baseline + 0.2) {
      return 'trendImproving';
    }
    if (current < baseline - 0.2) {
      return 'trendDeclining';
    }
    return 'trendStable';
  }

  String _translateTrend(String trendKey) {
    if (trendKey == 'trendImproving') {
      return context.t('trendImproving');
    }
    if (trendKey == 'trendDeclining') {
      return context.t('trendDeclining');
    }
    if (trendKey == 'trendStable') {
      return context.t('trendStable');
    }
    return trendKey;
  }

  String _localizeCanonicalToken(String value) {
    return AppTexts.localizeCanonicalText(context, value);
  }

  String _localizeConsecutiveLabel(String value) {
    final parts = value.split(' - ');
    if (parts.length == 2) {
      return '${_localizeCanonicalToken(parts[0])} - ${_localizeCanonicalToken(parts[1])}';
    }
    return _localizeCanonicalToken(value);
  }

  String _localizeTaskText(String task) {
    return AppTexts.localizeCanonicalText(context, task);
  }

  Future<void> _askTaskOutcome(String taskTitle) async {
    final now = DateTime.now();
    final startedAt =
        _taskStartedAt[taskTitle] ??
        now.subtract(_resolveInitialTaskDelay(taskTitle));
    final sensorEvents = await _storageService.loadSensorUsageBetween(
      startAt: startedAt,
      endAt: now,
    );
    final isSuspicious = _disciplineProtocolService.isSuspiciousDuringTask(
      events: sensorEvents,
      riskyHours: _riskyHours,
      startAt: startedAt,
      endAt: now,
    );

    if (!mounted) {
      return;
    }

    if (isSuspicious) {
      final taskStartTitle = context.t('taskStartTitle');
      await _protocolViolationService.logSuspiciousBehavior(
        taskTitle: taskTitle,
      );
      await _storageService.saveTaskResult(
        taskTitle: taskTitle,
        taskResult: 'suspicious_reset',
        completedAt: now,
      );
      await NotificationService.showFirstTaskTriggerNotification(
        taskTitle: taskStartTitle,
        taskDescription: taskTitle,
      );
      await NotificationService.scheduleTaskFollowUpReminder(
        taskTitle: taskTitle,
        delay: const Duration(minutes: 10),
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('taskSuspiciousReset'))));
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.t('taskOutcomeQuestion')),
          content: Text(_localizeTaskText(taskTitle)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.t('taskOutcomeNo')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.t('taskOutcomeYes')),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return;
    }

    await _storageService.saveTaskResult(
      taskTitle: taskTitle,
      taskResult: result ? 'willpower_success' : 'willpower_weakness',
      completedAt: DateTime.now(),
    );
    if (!result) {
      await _protocolViolationService.logWillpowerWeakness(
        taskTitle: taskTitle,
      );
    }
    await _storageService.resolveTaskFollowUpByTitle(taskTitle);
    _taskFollowUpTimers[taskTitle]?.cancel();
    _taskFollowUpTimers.remove(taskTitle);

    if (!mounted) {
      return;
    }

    setState(() {
      _taskStates[taskTitle] = result ? 'completed' : 'failed';
    });

    await _loadHomeMetrics();
    await _restorePendingFollowUps();
  }

  Future<void> _handleTaskNotificationAction(Map<String, String> event) async {
    final taskTitle = event['taskTitle']?.trim() ?? '';
    final actionId = event['actionId']?.trim() ?? '';
    if (taskTitle.isEmpty || actionId.isEmpty) {
      return;
    }

    if (actionId == 'task_done') {
      final now = DateTime.now();
      final delay = _resolveInitialTaskDelay(taskTitle);
      final followUpAt = now.add(delay);
      await _storageService.saveTaskResult(
        taskTitle: taskTitle,
        taskResult: 'started',
        completedAt: now,
      );
      _taskStartedAt[taskTitle] = now;
      await _storageService.saveTaskFollowUp(
        taskTitle: taskTitle,
        scheduledAt: followUpAt,
      );
      await NotificationService.showTaskTimerStartedNotification(
        taskTitle: taskTitle,
        duration: delay,
      );
      await NotificationService.scheduleTaskFollowUpReminder(
        taskTitle: taskTitle,
        delay: delay,
      );
      _scheduleLocalFollowUp(taskTitle, followUpAt);
      if (!mounted) {
        return;
      }
      setState(() {
        _taskStates[taskTitle] = 'deferred';
      });
      return;
    }

    if (actionId == 'task_not_now') {
      await _protocolViolationService.logDeferredStart(taskTitle: taskTitle);
      final delay = await _storageService.resolveAdaptivePostponeDelay();
      final followUpAt = DateTime.now().add(delay);
      await _storageService.saveTaskFollowUp(
        taskTitle: taskTitle,
        scheduledAt: followUpAt,
      );
      await NotificationService.scheduleFirstTaskTriggerNotification(
        taskDescription: taskTitle,
        delay: delay,
      );
      _scheduleLocalFollowUp(taskTitle, followUpAt);
      return;
    }

    if (actionId == 'followup_done' || actionId == 'smoked_yes') {
      final plannedMinutes = _resolveInitialTaskDelay(taskTitle).inMinutes;
      await _storageService.recordAdaptiveTaskOutcome(
        taskTitle: taskTitle,
        outcome: AdaptiveTaskOutcome.success,
        plannedDurationMinutes: plannedMinutes,
        scheduledAt: _taskStartedAt[taskTitle],
        respondedAt: DateTime.now(),
      );
      await _storageService.saveTaskResult(
        taskTitle: taskTitle,
        taskResult: 'willpower_success',
        completedAt: DateTime.now(),
      );
      await _storageService.resolveTaskFollowUpByTitle(taskTitle);
      _taskFollowUpTimers[taskTitle]?.cancel();
      _taskFollowUpTimers.remove(taskTitle);
      if (!mounted) {
        return;
      }
      setState(() {
        _taskStates[taskTitle] = 'completed';
      });
      await _loadHomeMetrics();
      await _restorePendingFollowUps();
      return;
    }

    if (actionId == 'followup_later' || actionId == 'smoked_no') {
      await _protocolViolationService.logFollowUpDeferred(
        taskTitle: taskTitle,
      );
      final delay = await _storageService.resolveAdaptivePostponeDelay();
      final followUpAt = DateTime.now().add(delay);
      final plannedMinutes = _resolveInitialTaskDelay(taskTitle).inMinutes;
      await _storageService.recordAdaptiveTaskOutcome(
        taskTitle: taskTitle,
        outcome: AdaptiveTaskOutcome.deferred,
        plannedDurationMinutes: plannedMinutes,
        scheduledAt: DateTime.now(),
        respondedAt: DateTime.now(),
      );
      await _storageService.resolveTaskFollowUpByTitle(taskTitle);
      await _storageService.saveTaskFollowUp(
        taskTitle: taskTitle,
        scheduledAt: followUpAt,
      );
      await NotificationService.scheduleTaskFollowUpReminder(
        taskTitle: taskTitle,
        delay: delay,
      );
      _scheduleLocalFollowUp(taskTitle, followUpAt);
    }
  }

  Future<void> _loadHomeMetrics() async {
    // İlk anketin quit date'ini al ve smoke-free days hesapla
    final initialRecord = await _storageService.loadSurveyHistory().then(
      (records) => records.where((r) => r.type == 'initial').firstOrNull,
    );
    int smokeFreeDays = 0;
    if (initialRecord?.quitDate != null) {
      smokeFreeDays = DateTime.now()
          .difference(initialRecord!.quitDate!)
          .inDays;
    }

    final registrationCompleted = await _storageService
        .loadInitialRegistrationCompleted();
    final notificationContextReason = await _storageService.loadSetting(
      'last_notification_context_reason',
    );
    final lastDate = await _storageService.loadLastSurveyDate();
    final latestBreath = await _storageService.loadLatestBreathRecord();
    final metrics = await _storageService.loadBreathMetrics();
    final breathProgress = await _storageService.loadBreathProgressReport();
    final consecutiveSmokingSummary = await _storageService
        .loadConsecutiveSmokingSummary();
    final taskOutcomeSummary = await _storageService.loadTaskOutcomeSummary();
    final durationBarrierPreference = await _storageService.loadSetting(
      'duration_barrier_preference',
    );
    final durationBarrierFrequencyPreference = await _storageService
        .loadSetting('duration_barrier_frequency_preference');
    final durationBarrierEnabledRaw = await _storageService.loadSetting(
      'duration_barrier_enabled',
    );
    final lastRespiratoryBurdenRaw = await _storageService.loadSetting(
      'last_respiratory_burden',
    );
    final lastRespiratoryStateRaw = await _storageService.loadSetting(
      'last_respiratory_state',
    );
    final behavior = registrationCompleted
        ? await _storageService.loadBehaviorDashboard()
        : await _storageService.loadLatestBehaviorSnapshot();
    AdaptiveTaskPlan? adaptivePlan;
    if (registrationCompleted) {
      final sleepRaw = await _storageService.loadSleepTime() ?? '21:00';
      final parts = sleepRaw.split(':');
      final sleepHour = int.tryParse(parts.first) ?? 21;
      final sleepMinute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      final now = DateTime.now();
      var sleepAt = DateTime(
        now.year,
        now.month,
        now.day,
        sleepHour,
        sleepMinute,
      );
      if (!sleepAt.isAfter(now)) {
        sleepAt = sleepAt.add(const Duration(days: 1));
      }

      adaptivePlan = await _storageService.buildAdaptiveNoSmokePlan(
        now: now,
        sleepAt: sleepAt,
        riskyHours: behavior?.riskyHours ?? const <String>[],
      );
    }
    final pendingFollowUps = await _storageService.loadPendingTaskFollowUps();
    final recentTaskEvents = await _storageService.loadRecentAdaptiveTaskEvents(
      limit: 100,
    );
    if (!mounted) return;
    setState(() {
      _smokeFreeDays = smokeFreeDays;
      _registrationCompleted = registrationCompleted;
      _lastSurveyDateText = lastDate == null
          ? 'noRecordYet'
          : '${lastDate.day}/${lastDate.month}/${lastDate.year}';
      _lastBreathText = latestBreath == null
          ? 'noRecordYet'
          : '${latestBreath.completedAt.day}/${latestBreath.completedAt.month}/${latestBreath.completedAt.year} • ${latestBreath.exhaleTestSeconds}${context.t('secShort')} / ${latestBreath.inhaleTestSeconds}${context.t('secShort')}';
      _latestExhaleSeconds = latestBreath?.exhaleTestSeconds ?? 0;
      _latestInhaleSeconds = latestBreath?.inhaleTestSeconds ?? 0;
      final now = DateTime.now();
      final doneToday =
          latestBreath != null &&
          latestBreath.completedAt.year == now.year &&
          latestBreath.completedAt.month == now.month &&
          latestBreath.completedAt.day == now.day;
      _dailyBreathStatus = doneToday
          ? 'breathTestDoneToday'
          : 'breathTestPendingToday';
      _dailyAverage = metrics['dailyAverage'] ?? 0;
      _weeklyAverage = metrics['weeklyAverage'] ?? 0;
      _monthlyAverage = metrics['monthlyAverage'] ?? 0;
      _weeklyImprovementText = _calculateImprovementLabel(
        _weeklyAverage,
        _monthlyAverage,
      );
      _monthlyImprovementText = _calculateImprovementLabel(
        _monthlyAverage,
        _dailyAverage,
      );
      _breathPreviousReportText = _buildBreathDeltaText(
        delta: (breathProgress['deltaFromPrevious'] as num?)?.toDouble() ?? 0,
        hasReference: breathProgress['hasPrevious'] == true,
        comparisonMode: 'previous',
      );
      _breathAverageReportText = _buildBreathDeltaText(
        delta:
            (breathProgress['deltaFromMonthlyAverage'] as num?)?.toDouble() ??
            0,
        hasReference: true,
        comparisonMode: 'average',
      );
      _adaptiveRiskScore = behavior?.riskScore ?? 0;
      _riskyTriggers = behavior?.riskyTriggers ?? const [];
      _riskyHours = behavior?.riskyHours ?? const [];
      _breathTrendText = behavior?.breathTrend ?? 'Stable';
      _breathTrendRecent = behavior?.breathTrendLast3 ?? 'stable';
      _progressSummaryText = behavior?.progressSummary ?? 'Stable';
      _adaptivePlanItems = adaptivePlan?.items ?? const [];
      _todaysTasks = _adaptivePlanItems.isNotEmpty
          ? _adaptivePlanItems.map((item) => item.taskTitle).toList()
          : behavior?.todaysTasks ?? const [];
      _coachCommands = behavior?.coachCommands ?? const [];
      _durationBarrierCommands = behavior?.durationBarrierCommands ?? const [];
      _durationBarrierHistoryCount = behavior?.durationBarrierHistoryCount ?? 0;
      _commandSuccessScores = behavior?.commandSuccessScores ?? const {};
      _commandCategoryScores = behavior?.commandCategoryScores ?? const {};
      _commandMixMode = behavior?.commandMixMode ?? 'balanced';
      _weeklySurveyRiskScore = behavior?.weeklySurveyRiskScore ?? 40;
      _weeklySurveyRiskLevel = behavior?.weeklySurveyRiskLevel ?? 'medium';
      _weeklyTopRiskDrivers = behavior?.weeklyTopRiskDrivers ?? const [];
      _riskExplanation = behavior?.riskExplanation ?? const [];
      _learnedWeights = behavior?.learnedWeights ?? const {};
      _predictedRiskWindow = behavior?.predictedRiskWindow ?? '...';
      _predictedTrigger = behavior?.predictedTrigger ?? '...';
      _predictionConfidence = behavior?.predictionConfidence ?? 0;
      _weeklyRiskTarget = behavior?.plan.weeklyRiskTarget ?? 0;
      _planCurrentDay = behavior?.plan.currentDay ?? 1;
      _planTargetDays = behavior?.plan.targetDays ?? 180;
      _planDaysRemaining = behavior?.plan.daysRemaining ?? 179;
      _planCadenceLevel = behavior?.plan.cadenceLevel ?? 'one_day';
      _consecutiveSmokingLatestText =
          consecutiveSmokingSummary['latest'] ?? context.t('noRecordYet');
      _consecutiveSmokingPreviousText =
          consecutiveSmokingSummary['previous'] ?? context.t('noRecordYet');
      _consecutiveSmokingTrendText =
          consecutiveSmokingSummary['trend'] ?? context.t('noRecordYet');
      _consecutiveSmokingStatusText =
          consecutiveSmokingSummary['status'] ?? context.t('noRecordYet');
      _successfulTaskCount = taskOutcomeSummary['successCount'] ?? 0;
      _failedTaskCount = taskOutcomeSummary['failureCount'] ?? 0;
      _recentSuccessCount = taskOutcomeSummary['recentSuccessCount'] ?? 0;
      _recentFailureCount = taskOutcomeSummary['recentFailureCount'] ?? 0;
      _notificationContextReasonText =
          (notificationContextReason == null ||
              notificationContextReason.trim().isEmpty)
          ? context.t('taskReasonNoPlanned')
          : notificationContextReason;
      _durationBarrierPreference = durationBarrierPreference ?? 'neutral';
      _durationBarrierFrequencyPreference =
          durationBarrierFrequencyPreference ?? 'orta';
      _durationBarrierEnabled = (durationBarrierEnabledRaw ?? '1') == '1';
      _lastRespiratoryBurden =
          int.tryParse(lastRespiratoryBurdenRaw ?? '25')?.clamp(0, 100) ?? 25;
      _lastRespiratoryState = lastRespiratoryStateRaw ?? 'stable';
      // Restore each task's real state from persisted history instead of
      // defaulting everything to 'new' — otherwise a task the user already
      // completed earlier today looks unfamiliar again after any process
      // restart (the in-memory _taskStates map doesn't survive one), which
      // was the direct cause of the mandatory-task screen re-triggering
      // for work that was already done.
      final deferredTitles = pendingFollowUps
          .map((row) => row['taskTitle'] as String)
          .toSet();
      final resolvedToday = <String, String>{};
      for (final event in recentTaskEvents) {
        final respondedAt = event.respondedAt;
        if (respondedAt.year == now.year &&
            respondedAt.month == now.month &&
            respondedAt.day == now.day) {
          resolvedToday[event.taskTitle] = switch (event.outcome) {
            AdaptiveTaskOutcome.success => 'completed',
            AdaptiveTaskOutcome.smoked => 'failed',
            _ => 'deferred',
          };
        }
      }
      for (final task in _todaysTasks) {
        if (_taskStates.containsKey(task)) {
          // Already has a live, in-session state (e.g. just completed) —
          // don't overwrite it with older persisted history.
          continue;
        }
        if (deferredTitles.contains(task)) {
          _taskStates[task] = 'deferred';
        } else if (resolvedToday.containsKey(task)) {
          _taskStates[task] = resolvedToday[task]!;
        } else {
          _taskStates[task] = 'new';
        }
      }
      _pendingFollowUps = pendingFollowUps;
    });

    await _refreshNextTaskNotificationInsight(pendingFollowUps);

    if (widget.autoCompleteRegistrationOnLoad &&
        !_registrationCompleted &&
        !_isCompletingRegistration) {
      unawaited(_completeRegistration());
    }

    if (_registrationCompleted) {
      await _ensureDailyBreathCadence();
      if (!mounted) {
        return;
      }
      await _ensureWeeklySurveyCadence();
      if (!mounted) {
        return;
      }
      unawaited(_notifyNewTasks());
      unawaited(_scheduleCoachCommandNotificationsIfNeeded());
      unawaited(_scheduleDurationBarrierNotificationsIfNeeded());
      unawaited(_presentMandatoryTaskIfNeeded());
      await _ensureMentorMessageCadence();
      await _ensureFakeCallBarrierCadence();
    }
  }

  /// Turns [SmokingTimePredictionEngine]'s likely-smoking hours into the
  /// hour-range strings [DisciplineProtocolService.generateUnpredictableMoments]
  /// expects, so the fake-call barrier fires when the user is actually
  /// likely to smoke rather than at a generic risky-hour signal. This is
  /// purely an internal scheduling input — never shown to the user. Falls
  /// back to [_riskyHours] when the prediction has nothing to say yet (e.g.
  /// survey data too sparse), so behavior is unchanged until real signal
  /// exists.
  Future<List<String>> _predictedFakeCallRiskyHours(DateTime now) async {
    final prediction = await _storageService.loadSmokingTimePrediction(
      now: now,
    );
    if (prediction.topHours.isEmpty) {
      return _riskyHours;
    }
    return prediction.topHours
        .map((hour) => '$hour:00-${(hour + 1) % 24}:00')
        .toList();
  }

  /// Handles the fake-call duration barrier's day-to-day lifecycle:
  /// - if a barrier's window has already ended, ask whether the user
  ///   stayed smoke-free and record the outcome;
  /// - otherwise, if none is active/pending and the duration-barrier
  ///   feature is enabled, schedule today's single unpredictable moment
  ///   (same idea as DisciplineProtocolService's adaptive task timing).
  Future<void> _ensureFakeCallBarrierCadence() async {
    if (!_registrationCompleted) {
      return;
    }

    final endsAt = await _storageService.loadFakeCallBarrierEndsAt();
    if (endsAt != null) {
      if (DateTime.now().isAfter(endsAt)) {
        await _askFakeCallBarrierOutcome();
      }
      return;
    }

    final enabled = _durationBarrierEnabled;
    if (!enabled) {
      return;
    }

    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final scheduledDateRaw = await _storageService.loadSetting(
      'fake_call_scheduled_date',
    );
    if (scheduledDateRaw == todayKey) {
      return;
    }

    final sleepRaw = await _storageService.loadSleepTime() ?? '21:00';
    final parts = sleepRaw.split(':');
    final sleepHour = int.tryParse(parts.first) ?? 21;
    final sleepMinute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    var sleepAt = DateTime(
      today.year,
      today.month,
      today.day,
      sleepHour,
      sleepMinute,
    );
    if (!sleepAt.isAfter(today)) {
      sleepAt = sleepAt.add(const Duration(days: 1));
    }

    final totalOutcomes = _recentSuccessCount + _recentFailureCount;
    final successRate = totalOutcomes == 0
        ? 0.5
        : _recentSuccessCount / totalOutcomes;

    // Recorded once per day here so StorageService.loadFakeCallBarrierDurationMinutes
    // can ease off the barrier duration on a worsening breath-test trend —
    // see that method for why. A worsening trend also earns an extra
    // barrier attempt today (more chances to catch a risky moment), while
    // improving/stable trends leave the existing success-streak-driven
    // cadence alone.
    await _storageService.saveBreathTrendToday(_breathTrendRecent);
    final moments = _disciplineProtocolService.generateUnpredictableMoments(
      now: today,
      sleepAt: sleepAt,
      riskyHours: await _predictedFakeCallRiskyHours(today),
      minCount: _breathTrendRecent == 'worsening' ? 2 : 1,
      successRate: successRate,
    );
    if (moments.isEmpty) {
      return;
    }

    final callerName = await _storageService.loadFakeCallerName();
    var fireAt = moments.first;
    if (await DevicePermissionService.isInPhoneCall()) {
      final afterCall = DateTime.now().add(
        FakeCallBarrierService.realCallCollisionDelay,
      );
      if (afterCall.isAfter(fireAt)) {
        fireAt = afterCall;
      }
    }
    await NotificationService.scheduleFakeCallBarrier(
      fireAt: fireAt,
      callerName: callerName,
    );
    await _storageService.saveSetting('fake_call_scheduled_date', todayKey);
  }

  Future<void> _askFakeCallBarrierOutcome() async {
    if (!mounted) {
      return;
    }
    final stayedSmokeFree = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('fakeCallOutcomeTitle')),
        content: Text(context.t('fakeCallOutcomeQuestion')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t('no')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.t('yes')),
          ),
        ],
      ),
    );
    if (stayedSmokeFree == null) {
      return;
    }
    await _fakeCallBarrierService.recordOutcome(succeeded: stayedSmokeFree);
  }

  /// Generates today's mentor message once per day (if not already done)
  /// and loads the latest one for [_buildMentorCard] to display.
  Future<void> _ensureMentorMessageCadence() async {
    final latest = await _storageService.loadLatestMentorMessage();
    final now = DateTime.now();
    final needsToday =
        latest == null ||
        latest.type == 'reframed_violation' ||
        latest.createdAt.year != now.year ||
        latest.createdAt.month != now.month ||
        latest.createdAt.day != now.day;

    final message = needsToday
        ? await _storageService.generateDailyMentorMessage(now: now)
        : latest;

    if (!mounted) {
      return;
    }
    setState(() {
      _latestMentorMessage = message;
    });
  }

  Future<void> _replyToMentorMessage(String reply) async {
    final message = _latestMentorMessage;
    if (message == null) {
      return;
    }
    await _storageService.replyToMentorMessage(message.id, reply);
    if (!mounted) {
      return;
    }
    setState(() {
      _latestMentorMessage = message.copyWith(read: true, userReply: reply);
    });
  }

  Future<void> _ensureDailyBreathCadence() async {
    if (!_registrationCompleted) {
      return;
    }

    final now = DateTime.now();
    final sleepTime = await _storageService.loadSleepTime() ?? '21:00';
    final wakeTime = await _storageService.loadSetting('wake_time') ?? '07:00';
    final preferredRaw = await _storageService.loadSetting(
      'daily_breath_test_target',
    );
    var preferred = int.tryParse(preferredRaw ?? '1') ?? 1;
    if (preferred < 1) {
      preferred = 1;
    }
    if (preferred > 4) {
      preferred = 4;
    }
    final adaptivePreferred = _resolveAdaptiveBreathReminderCount(preferred);

    final signature =
        '${now.year}-${now.month}-${now.day}|$sleepTime|$wakeTime|$adaptivePreferred|$_lastRespiratoryState|$_lastRespiratoryBurden';
    final existing = await _storageService.loadSetting(
      'last_daily_breath_schedule_signature',
    );
    if (existing != signature) {
      await NotificationService.scheduleAdaptiveDailyBreathReminders(
        sleepTime: sleepTime,
        wakeTime: wakeTime,
        minimumCount: 1,
        preferredCount: adaptivePreferred,
      );
      await _storageService.saveSetting(
        'last_daily_breath_schedule_signature',
        signature,
      );
    }

    if (_dailyBreathStatus != 'breathTestDoneToday') {
      await _presentDailyBreathMandatoryIfNeeded();
    }
  }

  int _resolveAdaptiveBreathReminderCount(int baseTarget) {
    var target = baseTarget.clamp(1, 4);

    // Keep reminders controlled while still reacting to respiratory worsening.
    if (_lastRespiratoryState == 'clinical_review_recommended') {
      target = (target + 1).clamp(2, 3);
    } else if (_lastRespiratoryState == 'monitor_closer') {
      target = target.clamp(1, 2);
      if (_lastRespiratoryBurden >= 55) {
        target = 2;
      }
    } else {
      if (_lastRespiratoryBurden < 30 && _adaptiveRiskScore < 45) {
        target = target.clamp(1, 2);
      }
    }

    return target;
  }

  Color _respiratoryBandColor() {
    switch (_lastRespiratoryState) {
      case 'clinical_review_recommended':
        return Colors.red.shade700;
      case 'monitor_closer':
        return Colors.orange.shade700;
      default:
        return Colors.green.shade700;
    }
  }

  String _respiratoryStateLabel() {
    switch (_lastRespiratoryState) {
      case 'clinical_review_recommended':
        return context.t('respClinicalReview');
      case 'monitor_closer':
        return context.t('respMonitorCloser');
      default:
        return context.t('respStable');
    }
  }

  Future<void> _presentDailyBreathMandatoryIfNeeded() async {
    if (!mounted ||
        !_registrationCompleted ||
        _dailyBreathMandatoryShownSession) {
      return;
    }
    if (_dailyBreathStatus == 'breathTestDoneToday') {
      return;
    }
    _dailyBreathMandatoryShownSession = true;

    final startNow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // barrierDismissible: false only blocks tap-outside — it does NOT
        // block the Android system/gesture back button, which would
        // otherwise pop this "mandatory" dialog for free. PopScope closes
        // that gap so the only way off this dialog is the button below.
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(context.t('dailyBreathMandatoryTitle')),
            content: Text(context.t('dailyBreathMandatoryContent')),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(context.t('dailyBreathMandatoryStart')),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || startNow != true) {
      return;
    }

    final packsPerDay = await _resolveLatestPacksPerDay();
    if (!mounted) {
      return;
    }

    // Routes through the consolidated daily check-in (breath exercise +
    // short recall survey) rather than straight into the breath test alone
    // — this is meant to be the day's one touchpoint, not just a breath
    // reminder.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DailyCheckInPage(name: widget.name, packsPerDay: packsPerDay),
      ),
    );

    if (!mounted) {
      return;
    }
    await _loadHomeMetrics();
  }

  Future<String> _resolveLatestPacksPerDay() async {
    final records = await _storageService.loadSurveyHistory();
    for (final record in records.reversed) {
      if ((record.packsPerDay).trim().isNotEmpty) {
        return record.packsPerDay;
      }
    }
    return '1 paketten az';
  }

  Future<void> _openBreathTestFromMenu() async {
    final packsPerDay = await _resolveLatestPacksPerDay();
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BreathTestPage(
          name: widget.name,
          packsPerDay: packsPerDay,
          navigateToHomeOnComplete: true,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadHomeMetrics();
  }

  Future<void> _openWeeklySurveyFromMenu() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeeklySurveyPage(
          navigateToHomeAfterSave: true,
          nameSeed: widget.name,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadHomeMetrics();
  }

  Future<void> _openPersonalProgressScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PersonalProgressPage()),
    );
  }

  Future<void> _openReports() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReportsPage()),
    );
  }

  Future<void> _ensureWeeklySurveyCadence() async {
    if (!_registrationCompleted || !mounted) {
      return;
    }

    final dueAt = await _storageService.loadWeeklySurveyDueDate();
    if (dueAt != null) {
      await NotificationService.scheduleWeeklySurveyDueReminder(dueAt: dueAt);
    }

    final overdue = await _storageService.isWeeklySurveyOverdue();
    if (!mounted) {
      return;
    }

    if (overdue) {
      if (_weeklySurveyMandatoryShown) {
        return;
      }
      _weeklySurveyMandatoryShown = true;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(context.t('weeklyMandatoryTitle')),
              content: Text(context.t('weeklyMandatoryContent')),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(context.t('weeklyMandatoryGo')),
                ),
              ],
            ),
          );
        },
      );

      if (!mounted) {
        return;
      }

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WeeklySurveyPage(
            navigateToHomeAfterSave: true,
            nameSeed: widget.name,
            isMandatory: true,
          ),
        ),
      );
      return;
    }

    if (_weeklySurveyPromptShownSession) {
      return;
    }

    final promptedToday = await _storageService
        .hasWeeklySurveyBeenPromptedToday();
    if (promptedToday) {
      return;
    }

    _weeklySurveyPromptShownSession = true;
    await _storageService.markWeeklySurveyPromptedToday();

    if (!mounted) {
      return;
    }

    final wantsWeeklySurvey = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.t('weeklySurvey')),
          content: Text(context.t('weeklySurveyPromptAsk')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.t('no')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.t('yes')),
            ),
          ],
        );
      },
    );

    if (!mounted || wantsWeeklySurvey != true) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeeklySurveyPage(
          navigateToHomeAfterSave: true,
          nameSeed: widget.name,
        ),
      ),
    );
  }

  /// Mirrors [_resolveDurationBarrierNotificationLimit]'s engagement-based
  /// throttling for the separate "coach command" notification stream, which
  /// previously always sent a fixed 3 pushes regardless of whether the user
  /// had been ignoring them. Returns 0 to suppress the burst entirely when
  /// the user has been consistently missing tasks and risk isn't elevated
  /// enough to justify pushing anyway.
  int _resolveCoachCommandNotificationLimit() {
    if (_recentFailureCount >= _recentSuccessCount + 4 &&
        _adaptiveRiskScore < 70) {
      return 0;
    }

    var limit = 3;
    if (_recentFailureCount > _recentSuccessCount + 2) {
      limit -= 1;
    } else if (_recentSuccessCount >= _recentFailureCount + 3) {
      limit -= 1;
    }
    return limit.clamp(1, 3);
  }

  Future<void> _scheduleCoachCommandNotificationsIfNeeded() async {
    if (!_registrationCompleted || _coachCommands.isEmpty) {
      return;
    }

    final limit = _resolveCoachCommandNotificationLimit();
    if (limit <= 0) {
      return;
    }

    final now = DateTime.now();
    final signature =
        '${now.year}-${now.month}-${now.day}|$_predictedRiskWindow|${_coachCommands.join('|')}';
    final existing = await _storageService.loadSetting(
      'last_coach_command_signature',
    );
    if (existing == signature) {
      return;
    }

    await NotificationService.scheduleCoachCommandNotifications(
      commands: _coachCommands,
      predictedRiskWindow: _predictedRiskWindow,
      maxNotifications: limit,
    );
    await _storageService.saveSetting(
      'last_coach_command_signature',
      signature,
    );
  }

  Future<void> _scheduleDurationBarrierNotificationsIfNeeded() async {
    if (!_registrationCompleted ||
        !_durationBarrierEnabled ||
        _durationBarrierCommands.isEmpty) {
      return;
    }

    final limit = _resolveDurationBarrierNotificationLimit();
    if (limit <= 0) {
      return;
    }
    final spacingMinutes = _resolveDurationBarrierNotificationSpacing();

    final now = DateTime.now();
    final signature =
        '${now.year}-${now.month}-${now.day}|BARRIER|$limit|$spacingMinutes|${_durationBarrierCommands.join('|')}';
    final existing = await _storageService.loadSetting(
      'last_duration_barrier_signature',
    );
    if (existing == signature) {
      return;
    }

    await NotificationService.scheduleCoachCommandNotifications(
      commands: _durationBarrierCommands,
      predictedRiskWindow: _predictedRiskWindow,
      maxNotifications: limit,
      spacingMinutes: spacingMinutes,
    );
    await _storageService.saveSetting(
      'last_duration_barrier_signature',
      signature,
    );
  }

  Future<void> _completeCoachCommand(String command) async {
    await _storageService.saveTaskResult(
      taskTitle: command,
      taskResult: 'willpower_success',
      completedAt: DateTime.now(),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t('commandSaved'))));
    await _loadHomeMetrics();
  }

  Future<void> _completeDurationBarrier(String command) async {
    final minutes = _extractDurationBarrierMinutes(command);
    if (!mounted) {
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final prompt = minutes == null
            ? context.t('barrierEvaluationPromptNoMinutes')
            : '$minutes ${context.t('barrierEvaluationPromptMinutes')}';
        return AlertDialog(
          title: Text(context.t('barrierEvaluationTitle')),
          content: Text(prompt),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.t('barrierFail')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.t('barrierSuccess')),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return;
    }

    _durationBarrierTimers[command]?.cancel();
    _durationBarrierTimers.remove(command);
    _durationBarrierEndsAt.remove(command);

    await _storageService.saveTaskResult(
      taskTitle: command,
      taskResult: result ? 'barrier_success' : 'barrier_failure',
      completedAt: DateTime.now(),
    );
    if (!result) {
      await _protocolViolationService.logDurationBarrierFailure(
        command: command,
      );
    }

    await _storageService.resolveTaskFollowUpByTitle(command);

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result
              ? context.t('barrierSavedSuccess')
              : context.t('barrierSavedFailure'),
        ),
      ),
    );
    await _loadHomeMetrics();
    _ensureDurationBarrierTicker();
  }

  Future<void> _startDurationBarrier(String command) async {
    final minutes = _extractDurationBarrierMinutes(command) ?? 30;
    if (_durationBarrierEndsAt.containsKey(command)) {
      return;
    }

    final duration = Duration(minutes: minutes);
    final endAt = DateTime.now().add(duration);

    await _storageService.saveTaskFollowUp(
      taskTitle: command,
      scheduledAt: endAt,
    );
    _durationBarrierEndsAt[command] = endAt;
    _scheduleLocalDurationBarrierFollowUp(command, endAt);
    await NotificationService.showDurationBarrierStartedNotification(
      taskTitle: command,
      duration: duration,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _taskStates[command] = 'deferred';
      _pendingFollowUps = [
        ..._pendingFollowUps,
        {'taskTitle': command, 'scheduledAt': endAt, 'status': 'pending'},
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${context.t('smokeFreeCounterTitle')}: ${_formatRemainingDuration(duration)}',
        ),
      ),
    );
  }

  Future<void> _deferCoachCommand(String command) async {
    await _storageService.saveTaskResult(
      taskTitle: command,
      taskResult: 'deferred',
      completedAt: DateTime.now(),
    );
    await NotificationService.scheduleFirstTaskTriggerNotification(
      taskDescription: command,
      delay: const Duration(minutes: 10),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t('commandDeferred10'))));
    await _loadHomeMetrics();
  }

  Future<void> _deferDurationBarrier(String command) async {
    await _storageService.saveTaskResult(
      taskTitle: command,
      taskResult: 'barrier_deferred',
      completedAt: DateTime.now(),
    );
    await NotificationService.scheduleFirstTaskTriggerNotification(
      taskDescription: command,
      delay: const Duration(minutes: 10),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t('barrierDeferred10'))));
    await _loadHomeMetrics();
  }

  int? _extractDurationBarrierMinutes(String command) {
    final match = RegExp(
      r'Sonraki\s+(\d+)\s+dakika',
      caseSensitive: false,
    ).firstMatch(command);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  int _resolveDurationBarrierNotificationLimit() {
    if (_durationBarrierHistoryCount == 0) {
      return 5;
    }

    var limit = _durationBarrierFrequencyPreference == 'az'
        ? 1
        : _durationBarrierFrequencyPreference == 'cok'
        ? 3
        : 2;

    if (_durationBarrierPreference == 'dislike') {
      limit -= 1;
    } else if (_durationBarrierPreference == 'like' &&
        _adaptiveRiskScore >= 70) {
      limit += 1;
    }

    if (_recentSuccessCount >= _recentFailureCount + 3) {
      limit -= 1;
    } else if (_recentFailureCount > _recentSuccessCount + 1 &&
        _adaptiveRiskScore >= 70) {
      limit += 1;
    }

    if (limit < 1) {
      return 1;
    }
    if (limit > 3) {
      return 3;
    }
    return limit;
  }

  int _resolveDurationBarrierNotificationSpacing() {
    var spacing = _durationBarrierFrequencyPreference == 'az'
        ? 45
        : _durationBarrierFrequencyPreference == 'cok'
        ? 20
        : 30;

    if (_durationBarrierPreference == 'dislike') {
      spacing += 15;
    }
    if (_recentSuccessCount >= _recentFailureCount + 3) {
      spacing += 10;
    }

    if (spacing < 15) {
      return 15;
    }
    if (spacing > 90) {
      return 90;
    }
    return spacing;
  }

  // Tasks are still meant to prompt the user several times across a day —
  // this only guards against the screen firing again within a short window
  // of its last appearance (e.g. a handful of app relaunches in a row),
  // not against it appearing multiple times per day, which is intended.
  static const Duration _mandatoryGateCooldown = Duration(minutes: 30);

  Future<void> _presentMandatoryTaskIfNeeded() async {
    if (!mounted || _mandatoryTaskShown || !_registrationCompleted) {
      return;
    }

    final lastShownAt = await _storageService.loadLastMandatoryGateShownAt();
    if (lastShownAt != null &&
        DateTime.now().difference(lastShownAt) < _mandatoryGateCooldown) {
      return;
    }

    // Don't interrupt a genuine phone call with the mandatory-command
    // screen — same posture already used for the fake-call barrier (see
    // FakeCallBarrierService.realCallCollisionDelay). This is a one-shot
    // check at present-time, not a live listener, so it retries once
    // after the same delay rather than trying to catch the exact moment
    // the call ends.
    if (await DevicePermissionService.isInPhoneCall()) {
      _mandatoryGateCallRetryTimer?.cancel();
      _mandatoryGateCallRetryTimer = Timer(
        FakeCallBarrierService.realCallCollisionDelay,
        () => unawaited(_presentMandatoryTaskIfNeeded()),
      );
      return;
    }

    String? taskTitle;
    if (_pendingFollowUps.isNotEmpty) {
      final first = _pendingFollowUps.first['taskTitle'] as String?;
      if (first != null && first.trim().isNotEmpty) {
        taskTitle = first;
      }
    }

    if ((taskTitle ?? '').isEmpty) {
      for (final task in _todaysTasks) {
        if ((_taskStates[task] ?? 'new') == 'new') {
          taskTitle = task;
          break;
        }
      }
    }

    if ((taskTitle ?? '').trim().isEmpty) {
      return;
    }

    _mandatoryTaskShown = true;
    // Guarded non-null by the empty-check above.
    await _protocolViolationService.logMandatoryGateShown(
      taskTitle: taskTitle!,
    );

    if (!mounted) {
      return;
    }
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MandatoryTaskPage(taskTitle: taskTitle!),
      ),
    );

    if (result == true) {
      await _startTaskFromMandatoryScreen(taskTitle);
    }
  }

  Future<void> _startTaskFromMandatoryScreen(String taskTitle) async {
    final now = DateTime.now();
    final delay = _resolveInitialTaskDelay(taskTitle);
    final followUpAt = now.add(delay);

    await _storageService.saveTaskResult(
      taskTitle: taskTitle,
      taskResult: 'started',
      completedAt: now,
    );
    _taskStartedAt[taskTitle] = now;
    await _storageService.saveTaskFollowUp(
      taskTitle: taskTitle,
      scheduledAt: followUpAt,
    );
    await NotificationService.showTaskTimerStartedNotification(
      taskTitle: taskTitle,
      duration: delay,
    );
    await NotificationService.scheduleTaskFollowUpReminder(
      taskTitle: taskTitle,
      delay: delay,
    );
    _scheduleLocalFollowUp(taskTitle, followUpAt);

    if (!mounted) {
      return;
    }
    setState(() {
      _taskStates[taskTitle] = 'deferred';
    });
  }

  Future<void> _notifyNewTasks() async {
    if (_todaysTasks.isEmpty) {
      return;
    }

    if (_adaptivePlanItems.isNotEmpty) {
      DateTime? nextAt;
      for (final item in _adaptivePlanItems) {
        final task = item.taskTitle;
        if (_notifiedTaskTitles.contains(task)) {
          continue;
        }
        if ((_taskStates[task] ?? 'new') != 'new') {
          continue;
        }

        var delay = item.scheduledAt.difference(DateTime.now());
        if (delay.inSeconds <= 0) {
          delay = const Duration(minutes: 1);
        }

        await NotificationService.scheduleFirstTaskTriggerNotification(
          taskDescription: task,
          delay: delay,
        );

        _notifiedTaskTitles.add(task);
        if (nextAt == null || item.scheduledAt.isBefore(nextAt)) {
          nextAt = item.scheduledAt;
        }
      }

      if (nextAt != null && mounted) {
        setState(() {
          _nextTaskNotificationText = _formatDateTime(nextAt!);
        });
      }
      return;
    }

    final timingContext = await _storageService.loadLatestTaskTimingContext();
    var index = 0;
    for (final task in _todaysTasks) {
      if (_notifiedTaskTitles.contains(task)) {
        continue;
      }
      if ((_taskStates[task] ?? 'new') != 'new') {
        continue;
      }
      final delay = _resolveTaskNotificationDelay(
        taskTitle: task,
        index: index,
        timingContext: timingContext,
      );
      await NotificationService.scheduleFirstTaskTriggerNotification(
        taskDescription: task,
        delay: delay,
      );

      _notifiedTaskTitles.add(task);
      index += 1;
    }

    await _ensureMinimumFiveNotificationsUntilSleep();
  }

  Future<void> _ensureMinimumFiveNotificationsUntilSleep() async {
    if (!_registrationCompleted) {
      return;
    }

    final sleep = await _storageService.loadSleepTime();
    final parts = (sleep ?? '21:00').split(':');
    final sleepHour = int.tryParse(parts.first) ?? 21;
    final sleepMinute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final now = DateTime.now();
    var sleepAt = DateTime(
      now.year,
      now.month,
      now.day,
      sleepHour,
      sleepMinute,
    );
    if (!sleepAt.isAfter(now)) {
      sleepAt = sleepAt.add(const Duration(days: 1));
    }

    if (!mounted) {
      return;
    }

    final fallbackTask = _todaysTasks.isNotEmpty
        ? _todaysTasks.first
        : context.t('firstTaskNoSmoke15');

    final schedule = _disciplineProtocolService.generateUnpredictableMoments(
      now: now,
      sleepAt: sleepAt,
      riskyHours: _riskyHours,
      minCount: 5,
      successRate: _currentSuccessRate(),
    );

    if (schedule.isEmpty) {
      return;
    }

    for (final at in schedule) {
      final delay = at.difference(DateTime.now());
      if (delay.inSeconds <= 0) {
        continue;
      }
      await NotificationService.scheduleFirstTaskTriggerNotification(
        taskDescription: fallbackTask,
        delay: delay,
      );
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _nextTaskNotificationText = _formatDateTime(schedule.first);
    });
  }

  Future<void> _refreshNextTaskNotificationInsight(
    List<Map<String, dynamic>> pendingFollowUps,
  ) async {
    String label = context.t('taskReasonNoPlanned');

    if (pendingFollowUps.isNotEmpty) {
      final sorted = [...pendingFollowUps]
        ..sort(
          (a, b) => (a['scheduledAt'] as DateTime).compareTo(
            b['scheduledAt'] as DateTime,
          ),
        );
      final nextAt = sorted.first['scheduledAt'] as DateTime;
      label = _formatDateTime(nextAt);
    } else {
      if (_adaptivePlanItems.isNotEmpty) {
        final now = DateTime.now();
        final upcoming = _adaptivePlanItems.where(
          (item) =>
              item.scheduledAt.isAfter(now) &&
              (_taskStates[item.taskTitle] ?? 'new') == 'new' &&
              !_notifiedTaskTitles.contains(item.taskTitle),
        );

        if (upcoming.isNotEmpty) {
          final sorted = [...upcoming]
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
          label = _formatDateTime(sorted.first.scheduledAt);
        }
      } else {
        final nextNewTaskIndex = _todaysTasks.indexWhere(
          (task) =>
              (_taskStates[task] ?? 'new') == 'new' &&
              !_notifiedTaskTitles.contains(task),
        );

        if (nextNewTaskIndex >= 0) {
          final timingContext = await _storageService
              .loadLatestTaskTimingContext();
          final delay = _resolveTaskNotificationDelay(
            taskTitle: _todaysTasks[nextNewTaskIndex],
            index: nextNewTaskIndex,
            timingContext: timingContext,
          );
          label = _formatDateTime(DateTime.now().add(delay));
        }
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _nextTaskNotificationText = label;
    });
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  Duration _resolveInitialTaskDelay(String taskTitle) {
    final adaptiveCanonical = RegExp(
      r'^ADAPTIVE_NO_SMOKE:(\d+)$',
      caseSensitive: false,
    ).firstMatch(taskTitle.trim());
    if (adaptiveCanonical != null) {
      final minutes = int.tryParse(adaptiveCanonical.group(1) ?? '');
      if (minutes != null && minutes > 0) {
        return Duration(minutes: minutes);
      }
    }

    final minuteMatch = RegExp(
      r'(\d+)\s*dakika',
      caseSensitive: false,
    ).firstMatch(taskTitle);
    if (minuteMatch != null) {
      final minutes = int.tryParse(minuteMatch.group(1) ?? '');
      if (minutes != null && minutes > 0) {
        return Duration(minutes: minutes);
      }
    }

    final hourMatch = RegExp(
      r'(\d+)\s*saat',
      caseSensitive: false,
    ).firstMatch(taskTitle);
    if (hourMatch != null) {
      final hours = int.tryParse(hourMatch.group(1) ?? '');
      if (hours != null && hours > 0) {
        return Duration(hours: hours);
      }
    }

    return const Duration(minutes: 30);
  }

  Duration _resolveTaskNotificationDelay({
    required String taskTitle,
    required int index,
    required Map<String, dynamic> timingContext,
  }) {
    final riskScore = _adaptiveRiskScore == 0
        ? widget.riskScore
        : _adaptiveRiskScore;
    final baseMinutes = riskScore >= 80
        ? 10
        : riskScore >= 60
        ? 20
        : riskScore >= 40
        ? 35
        : riskScore >= 20
        ? 50
        : 75;
    final gapMinutes = riskScore >= 80
        ? 12
        : riskScore >= 60
        ? 20
        : riskScore >= 40
        ? 30
        : riskScore >= 20
        ? 45
        : 60;

    var minutes = baseMinutes + (index * gapMinutes);
    final isDriving = timingContext['isDriving'] == true;
    final isSleepWindow = timingContext['isSleepWindow'] == true;
    final isActiveDuringSleep = timingContext['isActiveDuringSleep'] == true;
    final isWorkWindow = timingContext['isWorkWindow'] == true;
    final isTodayWorkingDay = timingContext['isTodayWorkingDay'] == true;
    final isBreakWindow = timingContext['isBreakWindow'] == true;
    final isPhoneBusy = timingContext['isPhoneBusy'] == true;
    final isLongIdle = timingContext['isLongIdle'] == true;
    final isWeekend = timingContext['isWeekend'] == true;
    final workplaceSmokingRule =
        (timingContext['workplaceSmokingRule'] as String?) ?? '';
    final weekendSmokingPattern =
        (timingContext['weekendSmokingPattern'] as String?) ?? 'Ayni';
    final minutesUntilWake =
        (timingContext['minutesUntilWake'] as num?)?.toInt() ?? 0;
    final minutesUntilWorkEnd =
        (timingContext['minutesUntilWorkEnd'] as num?)?.toInt() ?? 0;
    final minutesUntilNextBreak =
        (timingContext['minutesUntilNextBreak'] as num?)?.toInt() ?? -1;

    if (isDriving) {
      minutes += 20;
    }

    if (isSleepWindow) {
      if (isActiveDuringSleep) {
        minutes = 3 + (index * 3);
      } else {
        minutes = minutesUntilWake + 5 + (index * 5);
      }
    }

    if (isWorkWindow && isTodayWorkingDay) {
      if (workplaceSmokingRule == 'Hayır') {
        minutes = minutesUntilWorkEnd + 10 + (index * 5);
      } else if (workplaceSmokingRule == 'Sadece molalarda') {
        if (isBreakWindow) {
          minutes = minutes < 8 ? 8 + (index * 4) : minutes;
        } else if (minutesUntilNextBreak > 0) {
          minutes = minutesUntilNextBreak + 2 + (index * 4);
        } else {
          minutes = minutes < 25 ? 25 : minutes;
        }
      }
    }

    if (isWeekend && !isWorkWindow) {
      if (weekendSmokingPattern == 'HaftaSonuDahaFazla') {
        minutes -= 10;
      } else if (weekendSmokingPattern == 'HaftaSonuDahaAz') {
        minutes += 10;
      }
    }

    if (isPhoneBusy && !isSleepWindow && !isDriving) {
      minutes += 15;
    }

    if (isLongIdle && !isSleepWindow && !isDriving) {
      minutes = minutes > 5 ? 5 + (index * 5) : minutes;
    }

    if (taskTitle.contains('120 dakika') || taskTitle.contains('2 saat')) {
      minutes += 20;
    } else if (taskTitle.contains('90 dakika')) {
      minutes += 10;
    }

    return _disciplineProtocolService.computeUnpredictableDelay(
      baseDelay: Duration(minutes: minutes < 3 ? 3 : minutes),
      successRate: _currentSuccessRate(),
      minMinutes: 3,
    );
  }

  double _currentSuccessRate() {
    return _disciplineProtocolService.computeSuccessRate(
      successCount: _recentSuccessCount,
      failureCount: _recentFailureCount,
    );
  }

  String _buildBreathDeltaText({
    required double delta,
    required bool hasReference,
    required String comparisonMode,
  }) {
    if (!hasReference) {
      return context.t('breathNoReferenceYet');
    }

    final amount = delta.abs().toStringAsFixed(1);
    if (delta > 0.2) {
      return comparisonMode == 'previous'
          ? '${context.t('breathComparedPreviousImproved')} $amount${context.t('secShort')}'
          : '${context.t('breathComparedAverageImproved')} $amount${context.t('secShort')}';
    }
    if (delta < -0.2) {
      return comparisonMode == 'previous'
          ? '${context.t('breathComparedPreviousDeclined')} $amount${context.t('secShort')}'
          : '${context.t('breathComparedAverageDeclined')} $amount${context.t('secShort')}';
    }
    return comparisonMode == 'previous'
        ? context.t('breathComparedPreviousStable')
        : context.t('breathComparedAverageStable');
  }

  String _localizedRiskLabel() {
    final score = _adaptiveRiskScore == 0
        ? widget.riskScore
        : _adaptiveRiskScore;
    if (score >= 80) {
      return context.t('riskCritical');
    }
    if (score >= 60) {
      return context.t('riskHigh');
    }
    if (score >= 40) {
      return context.t('riskMedium');
    }
    return context.t('riskLow');
  }

  String _localizedWeeklyRiskLevel() {
    return AppTexts.localizeCanonicalText(context, _weeklySurveyRiskLevel);
  }

  void _showRegistrationError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _validateRegistrationInputs() async {
    final records = await _storageService.loadSurveyHistory();
    final hasInitialSurvey = await _storageService.hasCompletedInitialSurvey(
      records: records,
    );
    final hasBreathTest = records.any((record) => record.type == 'breath_test');
    return hasInitialSurvey && hasBreathTest;
  }

  Future<void> _createInitialProfileSnapshot() async {
    final records = await _storageService.loadSurveyHistory();
    final triggerMap = await _storageService.loadTriggerMapByRecordId();
    final contextMap = await _storageService.loadSurveyContextByRecordId();

    SurveyRecord? latestSurvey;
    SurveyRecord? latestBreath;
    for (final record in records.reversed) {
      if (latestSurvey == null &&
          (record.type == 'initial' || record.type == 'weekly')) {
        latestSurvey = record;
      }
      if (latestBreath == null && record.type == 'breath_test') {
        latestBreath = record;
      }
      if (latestSurvey != null && latestBreath != null) {
        break;
      }
    }

    if (latestSurvey == null) {
      throw StateError(
        'Initial/weekly survey record not found while creating profile snapshot.',
      );
    }
    if (latestBreath == null) {
      throw StateError(
        'Breath test record not found while creating profile snapshot.',
      );
    }

    final latestContext = contextMap[latestSurvey.id];
    final healthConditions =
        (latestContext?['healthConditions'] as List<String>?) ??
        const <String>[];
    final triggers = triggerMap[latestSurvey.id] ?? const <String>[];

    await _storageService.saveUserProfileSnapshot(
      UserProfileSnapshot(
        id: 'profile_init_${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
        riskScore: latestSurvey.riskScore,
        packsPerDay: latestSurvey.packsPerDay,
        firstCigaretteRange: 'unknown',
        smokeFreeRange: 'unknown',
        consecutiveSmokingHabit:
            latestSurvey.consecutiveSmokingHabit ?? 'Hayır',
        consecutiveSmokingCount: latestSurvey.consecutiveSmokingCount,
        triggers: triggers,
        healthConditions: healthConditions,
        profession: (latestContext?['profession'] as String?) ?? 'Belirtilmedi',
        sleepTime: (latestContext?['sleepTime'] as String?) ?? '21:00',
        wakeTime: (latestContext?['wakeTime'] as String?) ?? '07:00',
        latestExhaleSeconds: latestBreath.exhaleTestSeconds,
        latestInhaleSeconds: latestBreath.inhaleTestSeconds,
      ),
    );
  }

  Future<void> _completeRegistration() async {
    if (_isCompletingRegistration || _registrationCompleted) {
      return;
    }

    setState(() {
      _isCompletingRegistration = true;
    });

    try {
      debugPrint('[CompleteRegistration] Started');
      final isValid = await _validateRegistrationInputs();
      if (!isValid) {
        debugPrint('[CompleteRegistration] Validation failed');
        _showRegistrationError('Lütfen eksik alanları doldurun.');
        return;
      }

      try {
        debugPrint(
          '[CompleteRegistration] Running _createInitialProfileSnapshot',
        );
        await _createInitialProfileSnapshot();
      } catch (error, stackTrace) {
        debugPrint('[CompleteRegistration] Profile creation failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _showRegistrationError('Profil oluşturulamadı. Lütfen tekrar deneyin.');
        return;
      }

      debugPrint('[CompleteRegistration] Running loadBehaviorDashboard');
      try {
        await _storageService.loadBehaviorDashboard();
      } catch (error, stackTrace) {
        debugPrint(
          '[CompleteRegistration] loadBehaviorDashboard failed: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
        _showRegistrationError(
          'Risk analizi oluşturulamadı. Lütfen tekrar deneyin.',
        );
        return;
      }
      if (!mounted) {
        return;
      }
      final firstTask = context.t('firstTaskNoSmoke15');

      debugPrint('[CompleteRegistration] Creating first task: $firstTask');
      final createdAt = DateTime.now();
      const firstTaskDelay = Duration(minutes: 10);
      const followUpDelay = Duration(minutes: 5);
      const followUpRetryDelay = Duration(seconds: 30);

      try {
        await _storageService.saveTaskResult(
          taskTitle: firstTask,
          taskResult: 'created',
          completedAt: createdAt,
        );
        debugPrint('[CompleteRegistration] saveTaskResult(created) ok');
      } catch (error, stackTrace) {
        debugPrint(
          '[CompleteRegistration] saveTaskResult(created) failed: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }

      try {
        await NotificationService.scheduleFirstTaskTriggerNotification(
          taskDescription: firstTask,
          delay: firstTaskDelay,
        );

        await NotificationService.scheduleFirstTaskTriggerNotification(
          taskDescription: firstTask,
          delay: firstTaskDelay + followUpRetryDelay,
        );

        await NotificationService.scheduleFirstTaskTriggerNotification(
          taskDescription: firstTask,
          delay: firstTaskDelay + followUpDelay,
        );
        debugPrint(
          '[CompleteRegistration] first task notification scheduled (10m, +30s, +5m)',
        );
      } catch (error, stackTrace) {
        debugPrint(
          '[CompleteRegistration] first task notification scheduling failed (non-blocking): $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }

      debugPrint('[CompleteRegistration] Saving completion flag');
      try {
        await _storageService.saveInitialRegistrationCompleted(true);
        await _storageService.saveIsProfileCompleted(true);
      } catch (error, stackTrace) {
        debugPrint(
          '[CompleteRegistration] save registration flags failed: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
        _showRegistrationError(
          'Kayıt bayrağı kaydedilemedi. Lütfen tekrar deneyin.',
        );
        return;
      }
      debugPrint('[CompleteRegistration] Refreshing Home metrics');
      await _loadHomeMetrics();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('registrationCompleted'))),
      );
      debugPrint('[CompleteRegistration] Completed successfully');
    } catch (error, stackTrace) {
      debugPrint('[CompleteRegistration] Failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showRegistrationError(context.t('completeRegistrationError'));
    } finally {
      if (mounted) {
        setState(() {
          _isCompletingRegistration = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Center(
        child: SingleChildScrollView(
          // Extra bottom clearance so the floating SOS button (fixed to
          // the viewport, not the scroll position) never sits directly
          // over the last few lines of content.
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
          child: Column(
            children: [
              Text(
                '${context.t('welcome')}, ${widget.name}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              if (_latestMentorMessage != null) ...[
                _buildMentorCard(context),
                const SizedBox(height: 24),
              ],
              _buildStreakCounter(context),
              const SizedBox(height: 24),
              _buildHealthMetricsButton(context),
              const SizedBox(height: 24),
              _buildSummaryStats(context),
              const SizedBox(height: 16),
              _buildMainMenuCard(),
              const SizedBox(height: 16),
              _buildBreathTrendCard(),
              const SizedBox(height: 16),
              _buildAdaptiveInsightsCard(),
              const SizedBox(height: 16),
              _buildTaskReasonCard(),
              const SizedBox(height: 16),
              _buildTodayTaskCard(),
              const SizedBox(height: 12),
              _buildQuickLinkButtons(context),
              const SizedBox(height: 16),
              _buildConsecutiveSmokingCard(),
              const SizedBox(height: 24),
              if (!_registrationCompleted) _buildCompleteRegistrationButton(context),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('craving_sos_button'),
        onPressed: _openCravingSos,
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.sos),
        label: Text(context.t('cravingSosButton')),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NoSmokeLogo(size: 28),
          const SizedBox(width: 10),
          Text(context.t('home')),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
            if (!mounted) return;
            await _loadHomeMetrics();
          },
          icon: const Icon(Icons.settings_outlined),
          tooltip: context.t('settingsTitle'),
        ),
      ],
    );
  }

  Widget _buildMentorCard(BuildContext context) {
    final message = _latestMentorMessage!;
    final toneColor = switch (message.tone) {
      'coach' => AppTheme.noSmokeGreen,
      'supportive' => Colors.amber,
      _ => Colors.white70,
    };
    final answered = message.userReply != null;

    return Card(
      color: toneColor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: toneColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite, color: toneColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  context.t('mentorCardTitle'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: toneColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(message.text, style: const TextStyle(fontSize: 14, height: 1.5)),
            if (message.quickReplies.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (answered)
                Text(
                  '${context.t('mentorReplySentPrefix')}: ${message.userReply}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.white54,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: message.quickReplies
                      .map(
                        (reply) => OutlinedButton(
                          onPressed: () => _replyToMentorMessage(reply),
                          child: Text(reply),
                        ),
                      )
                      .toList(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCounter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.teal.withAlpha((255 * 0.2).toInt()),
        border: Border.all(color: Colors.teal, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '🔥 ${context.t('smokeFreeStreak')}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_smokeFreeDays',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          Text(
            context.t('dayUnit'),
            style: const TextStyle(fontSize: 18, color: Colors.teal),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetricsButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HealthMetricsPage(name: widget.name),
            ),
          );
        },
        icon: const Icon(Icons.show_chart),
        label: Text(context.t('healthMetrics')),
      ),
    );
  }

  Widget _buildSummaryStats(BuildContext context) {
    return Column(
      children: [
        Text(
          '${context.t('riskLevel')}: ${_localizedRiskLabel()}',
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          '${context.t('riskScore')}: ${_adaptiveRiskScore == 0 ? widget.riskScore : _adaptiveRiskScore} / 100',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 12),
        Text(
          '${context.t('lastSurveyDate')}: ${_lastSurveyDateText == 'noRecordYet' ? context.t('noRecordYet') : _lastSurveyDateText}',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        Text(
          '${context.t('lastBreathTest')}: ${_lastBreathText == 'noRecordYet' ? context.t('noRecordYet') : _lastBreathText}',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          '${context.t('dailyBreathStatus')}: ${context.t(_dailyBreathStatus)}',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          '${context.t('lastExhale')}: $_latestExhaleSeconds${context.t('secShort')} • ${context.t('lastInhale')}: $_latestInhaleSeconds${context.t('secShort')}',
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildQuickLinkButtons(BuildContext context) {
    return Column(
      children: [
        if (_pendingFollowUps.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TaskFollowUpPage()),
                );
                if (!mounted) {
                  return;
                }
                await _loadHomeMetrics();
                await _restorePendingFollowUps();
              },
              child: Text(context.t('openTaskFollowUpScreen')),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProtocolViolationsPage(),
                ),
              );
            },
            child: Text(context.t('openViolationReportScreen')),
          ),
        ),
      ],
    );
  }

  Widget _buildCompleteRegistrationButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isCompletingRegistration ? null : _completeRegistration,
        child: Text(context.t('completeRegistration')),
      ),
    );
  }

  void _openCravingSos() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CravingSosPage()));
  }

  Widget _buildAdaptiveInsightsCard() {
    final triggers = _riskyTriggers.isEmpty
        ? context.t('noRecordYet')
        : _riskyTriggers.map(_localizeCanonicalToken).join(', ');
    final hours = _riskyHours.isEmpty
        ? context.t('noRecordYet')
        : _riskyHours.join(', ');
    final breathTrend = _breathTrendText == 'Improving'
        ? context.t('trendImproving')
        : _breathTrendText == 'Declining'
        ? context.t('trendDeclining')
        : _breathTrendText == 'Stable'
        ? context.t('trendStable')
        : _breathTrendText;
    final progress = _progressSummaryText == 'Improving'
        ? context.t('trendImproving')
        : _progressSummaryText == 'Declining'
        ? context.t('trendDeclining')
        : _progressSummaryText == 'Stable'
        ? context.t('trendStable')
        : _progressSummaryText;
    final cadenceLabel = _planCadenceLevel == 'week'
        ? context.t('goal180CadenceWeek')
        : _planCadenceLevel == 'two_days'
        ? context.t('goal180CadenceTwoDays')
        : context.t('goal180CadenceOneDay');
    final guideText = _planCurrentDay >= 120
        ? (_failedTaskCount > _successfulTaskCount
              ? context.t('goal180GuideLateHard')
              : context.t('goal180GuideLate'))
        : _planCurrentDay >= 60
        ? (_failedTaskCount > _successfulTaskCount
              ? context.t('goal180GuideMidHard')
              : context.t('goal180GuideMid'))
        : context.t('goal180GuideEarly');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('adaptiveSummary'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('${context.t('riskyTriggers')}: $triggers'),
            const SizedBox(height: 6),
            Text('${context.t('riskyHours')}: $hours'),
            const SizedBox(height: 6),
            Text('${context.t('breathImprovementSummary')}: $breathTrend'),
            const SizedBox(height: 6),
            Text('${context.t('progressSummary')}: $progress'),
            const SizedBox(height: 6),
            Text('${context.t('predictedRiskTime')}: $_predictedRiskWindow'),
            const SizedBox(height: 6),
            Text('${context.t('predictedTrigger')}: $_predictedTrigger'),
            const SizedBox(height: 6),
            Text(
              '${context.t('predictionConfidence')}: %$_predictionConfidence',
            ),
            const SizedBox(height: 6),
            Text('${context.t('weeklyRiskTarget')}: $_weeklyRiskTarget / 100'),
            const SizedBox(height: 6),
            Text(
              '${context.t('weeklyRiskLine')}: $_weeklySurveyRiskScore/100 (${_localizedWeeklyRiskLevel()})',
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _respiratoryBandColor().withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _respiratoryBandColor()),
              ),
              child: Text(
                '${context.t('respiratoryStatusLine')}: ${_respiratoryStateLabel()} • ${context.t('levelLabel')}: $_lastRespiratoryBurden/100',
                style: TextStyle(
                  color: _respiratoryBandColor(),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_weeklyTopRiskDrivers.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${context.t('weeklyTopDriversLine')}: ${_weeklyTopRiskDrivers.join(' | ')}',
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Text('${context.t('commandModeLabel')}: '),
                _buildCommandMixBadge(_commandMixMode),
              ],
            ),
            if (_learnedWeights.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${context.t('learnedWeightsLabel')}: ${_formatLearnedWeights(_learnedWeights)}',
              ),
            ],
            if (_coachCommands.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                context.t('personalCommandsTitle'),
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ..._coachCommands.map(
                (command) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('- $command'),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => _completeCoachCommand(command),
                            child: Text(context.t('doneShort')),
                          ),
                          TextButton(
                            onPressed: () => _deferCoachCommand(command),
                            child: Text(context.t('defer10m')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_durationBarrierCommands.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                context.t('durationBarriersTitle'),
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              if (_activeDurationBarriers().isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('smokeFreeCounterTitle'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${context.t('smokeFreeCounterRemaining')}: ${_formatRemainingDuration((_activeDurationBarriers().first['scheduledAt'] as DateTime).difference(DateTime.now()))}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
              ..._durationBarrierCommands.map(
                (command) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('- $command'),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => _startDurationBarrier(command),
                            child: Text(context.t('start')),
                          ),
                          TextButton(
                            onPressed: () => _deferDurationBarrier(command),
                            child: Text(context.t('defer10m')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_coachCommands.isNotEmpty &&
                _commandSuccessScores.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${context.t('commandScoreLabel')}: ${_formatCommandScores(_coachCommands, _commandSuccessScores)}',
              ),
            ],
            if (_commandCategoryScores.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${context.t('categoryInsightLabel')}: ${_formatCategoryScores(_commandCategoryScores)}',
              ),
            ],
            if (_riskExplanation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                context.t('riskScoreExplanationTitle'),
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ..._riskExplanation.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('- $line'),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '${context.t('goal180ProgressLabel')}: $_planCurrentDay / $_planTargetDays ${context.t('days')}',
            ),
            const SizedBox(height: 6),
            Text(
              '${context.t('goal180RemainingLabel')}: $_planDaysRemaining ${context.t('days')}',
            ),
            const SizedBox(height: 6),
            Text('${context.t('goal180CadenceLabel')}: $cadenceLabel'),
            const SizedBox(height: 6),
            Text(guideText),
          ],
        ),
      ),
    );
  }

  Future<void> _logSmokingNow() async {
    // Optional, non-forcing real-time log: one tap, no follow-up questions,
    // with a brief undo window for accidental taps. This is purely a
    // ground-truth data point for SmokingTimePredictionEngine — it does not
    // gate anything or trigger any other flow.
    final eventId = await _storageService.logSmokingNow();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.t('smokingLoggedConfirmation')),
          action: SnackBarAction(
            label: context.t('undo'),
            onPressed: () {
              unawaited(_storageService.deleteSmokingEvent(eventId));
            },
          ),
        ),
      );
  }

  Widget _buildMainMenuCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('quickMenuTitle'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 160,
                  child: ElevatedButton.icon(
                    onPressed: _openBreathTestFromMenu,
                    icon: const Icon(Icons.air),
                    label: Text(context.t('menuBreathTest')),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: OutlinedButton.icon(
                    onPressed: _openWeeklySurveyFromMenu,
                    icon: const Icon(Icons.assignment),
                    label: Text(context.t('menuWeeklySurvey')),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: OutlinedButton.icon(
                    onPressed: _openPersonalProgressScreen,
                    icon: const Icon(Icons.insights),
                    label: Text(context.t('menuPersonalProgress')),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: OutlinedButton.icon(
                    onPressed: _openReports,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(context.t('menuReports')),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProtocolViolationsPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.report_gmailerrorred),
                    label: Text(context.t('menuViolationReport')),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SurveyHistoryPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history),
                    label: Text(context.t('menuSurveyHistory')),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: OutlinedButton.icon(
                    onPressed: _logSmokingNow,
                    icon: const Icon(Icons.smoking_rooms_outlined),
                    label: Text(context.t('menuLogSmokingNow')),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final packsPerDay = await _resolveLatestPacksPerDay();
                      if (!mounted) return;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DailyCheckInPage(
                            name: widget.name,
                            packsPerDay: packsPerDay,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.nights_stay_outlined),
                    label: Text(context.t('menuDailyCheckIn')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTaskCard() {
    final tasks = _todaysTasks.isEmpty
        ? <String>[context.t('noTaskToday')]
        : _todaysTasks;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('todaysTasks'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_pendingFollowUps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${context.t('taskFollowUpPendingCount')}: ${_pendingFollowUps.length}',
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${context.t('successfulTaskCount')}: $_successfulTaskCount • ${context.t('failedTaskCount')}: $_failedTaskCount',
              ),
            ),
            ...tasks.map((task) {
              if (_todaysTasks.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('- $task'),
                );
              }
              final state = _taskStates[task] ?? 'new';
              final translatedState = state == 'completed'
                  ? context.t('taskStateCompleted')
                  : state == 'failed'
                  ? context.t('taskStateFailed')
                  : state == 'deferred'
                  ? context.t('taskStateDeferred')
                  : context.t('taskStateNew');
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('- ${_localizeTaskText(task)}'),
                    const SizedBox(height: 6),
                    Text(translatedState, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskReasonCard() {
    final cadenceLabel = _planCadenceLevel == 'week'
        ? context.t('goal180CadenceWeek')
        : _planCadenceLevel == 'two_days'
        ? context.t('goal180CadenceTwoDays')
        : context.t('goal180CadenceOneDay');
    final recentTotal = _recentSuccessCount + _recentFailureCount;
    final successRatioText = recentTotal == 0
        ? context.t('taskReasonNoRecentData')
        : '%${((_recentSuccessCount * 100) / recentTotal).round()} ($_recentSuccessCount/$recentTotal)';
    final decisionReasons = _buildTaskDecisionReasons();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('taskReasonCardTitle'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              '${context.t('taskReasonRiskLine')}: ${_adaptiveRiskScore == 0 ? widget.riskScore : _adaptiveRiskScore}/100',
            ),
            const SizedBox(height: 6),
            Text('${context.t('taskReasonRecentRatio')}: $successRatioText'),
            const SizedBox(height: 6),
            Text('${context.t('taskReasonCadence')}: $cadenceLabel'),
            const SizedBox(height: 6),
            Text(
              '${context.t('taskReasonNextNotification')}: $_nextTaskNotificationText',
            ),
            const SizedBox(height: 6),
            Text(
              '${context.t('notificationContextReasonLabel')}: $_notificationContextReasonText',
            ),
            const SizedBox(height: 6),
            Text(
              '${context.t('taskReasonCause')}:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            ...decisionReasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        reason.key,
                        size: 14,
                        color: _reasonIconColor(reason.key),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(reason.value)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MapEntry<IconData, String>> _buildTaskDecisionReasons() {
    final effectiveRisk = _adaptiveRiskScore == 0
        ? widget.riskScore
        : _adaptiveRiskScore;
    final recentTotal = _recentSuccessCount + _recentFailureCount;

    final fragments = <MapEntry<IconData, String>>[];

    if (recentTotal == 0) {
      fragments.add(
        MapEntry(Icons.tune_rounded, context.t('taskReasonCauseBootstrap')),
      );
    } else if (_recentFailureCount > _recentSuccessCount) {
      fragments.add(
        MapEntry(
          Icons.trending_up_rounded,
          context.t('taskReasonCauseFailurePressure'),
        ),
      );
    } else if (_recentSuccessCount >= _recentFailureCount + 3) {
      fragments.add(
        MapEntry(
          Icons.verified_rounded,
          context.t('taskReasonCauseSuccessStability'),
        ),
      );
    }

    if (effectiveRisk >= 70) {
      fragments.add(
        MapEntry(
          Icons.warning_amber_rounded,
          context.t('taskReasonCauseHighRisk'),
        ),
      );
    } else if (effectiveRisk <= 35) {
      fragments.add(
        MapEntry(
          Icons.shield_moon_rounded,
          context.t('taskReasonCauseLowRisk'),
        ),
      );
    }

    if (_riskyTriggers.isNotEmpty) {
      fragments.add(
        MapEntry(
          Icons.local_fire_department_rounded,
          '${context.t('taskReasonCauseTopTrigger')} ${_localizeCanonicalToken(_riskyTriggers.first)}',
        ),
      );
    }

    if (_riskyHours.isNotEmpty) {
      fragments.add(
        MapEntry(
          Icons.schedule_rounded,
          '${context.t('taskReasonCauseTopHour')} ${_riskyHours.first}',
        ),
      );
    }

    if (fragments.isEmpty) {
      return [
        MapEntry(Icons.balance_rounded, context.t('taskReasonCauseBalanced')),
      ];
    }
    return fragments;
  }

  Color _reasonIconColor(IconData icon) {
    if (icon == Icons.warning_amber_rounded) {
      return Colors.redAccent;
    }
    if (icon == Icons.trending_up_rounded) {
      return Colors.orangeAccent;
    }
    if (icon == Icons.local_fire_department_rounded) {
      return Colors.deepOrangeAccent;
    }
    if (icon == Icons.schedule_rounded) {
      return Colors.lightBlueAccent;
    }
    if (icon == Icons.verified_rounded) {
      return Colors.lightGreenAccent;
    }
    if (icon == Icons.shield_moon_rounded || icon == Icons.balance_rounded) {
      return Colors.tealAccent;
    }
    if (icon == Icons.tune_rounded) {
      return Colors.purpleAccent;
    }
    return Colors.white70;
  }

  Widget _buildBreathTrendCard() {
    final maxValue = [
      _dailyAverage,
      _weeklyAverage,
      _monthlyAverage,
    ].reduce((a, b) => a > b ? a : b).clamp(1, 100).toDouble();
    final values = [
      (_dailyAverage / maxValue).clamp(0.0, 1.0),
      (_weeklyAverage / maxValue).clamp(0.0, 1.0),
      (_monthlyAverage / maxValue).clamp(0.0, 1.0),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('breathTrend'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTrendBar(context.t('daily'), values[0], _dailyAverage),
                _buildTrendBar(context.t('weekly'), values[1], _weeklyAverage),
                _buildTrendBar(
                  context.t('monthly'),
                  values[2],
                  _monthlyAverage,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${context.t('weeklyImprovement')}: ${_translateTrend(_weeklyImprovementText)}',
            ),
            const SizedBox(height: 6),
            Text(
              '${context.t('monthlyImprovement')}: ${_translateTrend(_monthlyImprovementText)}',
            ),
            const SizedBox(height: 6),
            Text(
              '${context.t('breathPreviousComparison')}: $_breathPreviousReportText',
            ),
            const SizedBox(height: 6),
            Text(
              '${context.t('breathAverageComparison')}: $_breathAverageReportText',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendBar(String label, double ratio, double value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Container(
              height: 90,
              width: double.infinity,
              alignment: Alignment.bottomCenter,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(8),
              ),
              child: FractionallySizedBox(
                heightFactor: ratio == 0 ? 0.02 : ratio,
                widthFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: ratio >= 0.7
                        ? Colors.green
                        : ratio >= 0.4
                        ? Colors.orange
                        : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(
              '${value.toStringAsFixed(1)}${context.t('secShort')}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsecutiveSmokingCard() {
    final latest = _consecutiveSmokingLatestText == 'noRecordYet'
        ? context.t('noRecordYet')
        : _localizeConsecutiveLabel(_consecutiveSmokingLatestText);
    final status = _consecutiveSmokingStatusText == 'noRecordYet'
        ? context.t('noRecordYet')
        : _localizeConsecutiveLabel(_consecutiveSmokingStatusText);
    final trend = _consecutiveSmokingTrendText == 'noRecordYet'
        ? context.t('noRecordYet')
        : _consecutiveSmokingTrendText == 'trendStable'
        ? context.t('trendStable')
        : _consecutiveSmokingTrendText == 'trendImproving'
        ? context.t('trendImproving')
        : _consecutiveSmokingTrendText == 'trendDeclining'
        ? context.t('trendDeclining')
        : _consecutiveSmokingTrendText;
    final previous = _consecutiveSmokingPreviousText == 'noRecordYet'
        ? context.t('noRecordYet')
        : _consecutiveSmokingPreviousText == 'firstEvaluation'
        ? context.t('firstEvaluation')
        : _localizeConsecutiveLabel(_consecutiveSmokingPreviousText);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('chainSmokingTrend'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('${context.t('chainSmokingLatest')}: $latest'),
            const SizedBox(height: 6),
            Text('${context.t('status')}: $status'),
            const SizedBox(height: 6),
            Text('${context.t('progressRegression')}: $trend'),
            const SizedBox(height: 6),
            Text('${context.t('previousRecord')}: $previous'),
          ],
        ),
      ),
    );
  }

  String _formatLearnedWeights(Map<String, double> weights) {
    if (weights.isEmpty) {
      return '-';
    }

    final orderedKeys = ['smoking', 'breath', 'consecutive', 'trigger', 'hour'];
    final labels = {
      'smoking': 'sigara',
      'breath': 'nefes',
      'consecutive': 'ardisik',
      'trigger': 'tetik',
      'hour': 'saat',
    };

    final parts = <String>[];
    for (final key in orderedKeys) {
      final value = weights[key];
      if (value == null) {
        continue;
      }
      parts.add('${labels[key]}:${value.toStringAsFixed(2)}');
    }
    return parts.join(' • ');
  }

  String _formatCommandScores(
    List<String> commands,
    Map<String, double> scores,
  ) {
    final parts = <String>[];
    final take = commands.length < 3 ? commands.length : 3;
    for (var i = 0; i < take; i++) {
      final command = commands[i];
      final score = ((scores[command] ?? 0.5) * 100).round();
      parts.add('K${i + 1}:%$score');
    }
    return parts.join(' • ');
  }

  String _formatCategoryScores(Map<String, double> scores) {
    if (scores.isEmpty) {
      return '-';
    }

    final labels = {
      'breath': 'nefes',
      'delay': 'erteleme',
      'trigger': 'tetikleyici',
      'reduction': 'azaltma',
      'routine': 'rutin',
    };

    final entries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final parts = <String>[];
    final take = entries.length < 3 ? entries.length : 3;
    for (var i = 0; i < take; i++) {
      final entry = entries[i];
      parts.add(
        '${labels[entry.key] ?? entry.key}:%${(entry.value * 100).round()}',
      );
    }
    return parts.join(' • ');
  }

  Widget _buildCommandMixBadge(String mode) {
    final normalized = mode.trim().toLowerCase();
    final label = normalized == 'aggressive'
        ? 'Agresif'
        : normalized == 'protective'
        ? 'Koruyucu'
        : 'Dengeli';

    final background = normalized == 'aggressive'
        ? Colors.red.withValues(alpha: 0.18)
        : normalized == 'protective'
        ? Colors.lightGreen.withValues(alpha: 0.18)
        : Colors.blue.withValues(alpha: 0.18);

    final foreground = normalized == 'aggressive'
        ? Colors.redAccent
        : normalized == 'protective'
        ? Colors.lightGreenAccent
        : Colors.lightBlueAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
