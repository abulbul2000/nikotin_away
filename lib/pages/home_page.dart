import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../models/survey_record.dart';
import '../models/user_profile_snapshot.dart';
import '../pages/breath_test_page.dart';
import '../pages/health_metrics_page.dart';
import '../pages/mandatory_task_page.dart';
import '../pages/personal_progress_page.dart';
import '../pages/protocol_violations_page.dart';
import '../pages/task_follow_up_page.dart';
import '../pages/weekly_survey_page.dart';
import '../services/discipline_protocol_service.dart';
import '../services/notification_service.dart';
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
  final DisciplineProtocolService _disciplineProtocolService =
      DisciplineProtocolService();
  final Map<String, String> _taskStates = {};
  final Map<String, Timer> _taskFollowUpTimers = {};
  final Map<String, DateTime> _taskStartedAt = {};
  final Set<String> _notifiedTaskTitles = <String>{};
  StreamSubscription<Map<String, String>>? _taskActionSubscription;
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
  }

  @override
  void dispose() {
    _taskActionSubscription?.cancel();
    for (final timer in _taskFollowUpTimers.values) {
      timer.cancel();
    }
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
      _scheduleLocalFollowUp(taskTitle, scheduledAt);
      _taskStates[taskTitle] = 'deferred';
    }
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
    switch (value.trim()) {
      case 'Evet':
        return context.t('yes');
      case 'Hayır':
      case 'Hayir':
        return context.t('no');
      case '2 adet':
        return context.t('twoCig');
      case '3 adet':
        return context.t('threeCig');
      case '4 adet':
        return context.t('fourCig');
      case '5+ adet':
        return context.t('fivePlusCig');
      case 'Kahve':
        return context.t('triggerCoffee');
      case 'Yemek Sonrasi':
        return context.t('triggerMeal');
      case 'Arac':
        return context.t('triggerDriving');
      case 'Stres':
        return context.t('triggerStress');
      case 'Telefon':
        return context.t('triggerPhone');
      case 'Sosyal Ortam':
        return context.t('triggerSocial');
      case 'Alkol':
        return context.t('triggerAlcohol');
      default:
        return value;
    }
  }

  String _localizeConsecutiveLabel(String value) {
    final parts = value.split(' - ');
    if (parts.length == 2) {
      return '${_localizeCanonicalToken(parts[0])} - ${_localizeCanonicalToken(parts[1])}';
    }
    return _localizeCanonicalToken(value);
  }

  String _localizeTaskText(String task) {
    final taskMap = <String, String>{
      'Ilk sigarayi 10 dakika ertele': context.t('taskDelayFirstSmoke10'),
      'Bir bardak su ic': context.t('taskDrinkWater'),
      '2 dakikalik nefes egzersizi yap': context.t('taskBreathExercise2'),
      '10 dakika sigarasiz kal': context.t('taskNoSmoke10'),
      'Kriz anini not et': context.t('taskNoteCraving'),
      'Ilk sigarayi 25 dakika ertele': context.t('taskDelayFirstSmoke25'),
      'Bugun bir sigarayi atla': context.t('taskSkipOneCig'),
      '30 dakika sigarasiz kal': context.t('taskNoSmoke30'),
      'Riskli saatte seker sakiz kullan': context.t('taskUseGumAtRiskHour'),
      '45 dakika sigarasiz kal': context.t('taskNoSmoke45'),
      '60 dakika sigarasiz kal': context.t('taskNoSmoke60'),
      'Bugun 2 sigara eksik ic': context.t('taskSmokeTwoLess'),
      '90 dakika sigarasiz kal': context.t('taskNoSmoke90'),
      '120 dakika sigarasiz kal': context.t('taskNoSmoke120'),
      'Aksam saatinde destek kisisiyle iletisim kur': context.t(
        'taskContactSupportEvening',
      ),
      '1 gun sigarasiz kalma gorevi: bugun tum kriz anlarinda sigarayi erteleyin.':
          context.t('taskPlanOneDayDelayAllCravings'),
      '1 gun sigarasiz kalma gorevi: ilk sigarayi en az 90 dakika erteleyin.':
          context.t('taskPlanOneDayDelayFirst90'),
      '2 gun sigarasiz kalma gorevi: 48 saat boyunca tetikleyicilerde sigarayi erteleyin.':
          context.t('taskPlanTwoDaysDelayTriggers'),
      '2 gun sigarasiz kalma plani: kriz aninda 10 derin nefes + su uygulayin.':
          context.t('taskPlanTwoDaysBreathAndWater'),
      '1 hafta sigarasiz kalma hedefi: 7 gun boyunca tum gorevleri tamamlayin.':
          context.t('taskPlanOneWeekCompleteAll'),
    };

    return taskMap[task] ?? task;
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
      await _storageService.saveProtocolViolation(
        type: 'suspicious_behavior',
        severity: 'high',
        source: 'app_flow',
        taskTitle: taskTitle,
        details:
            'Suspicious movement/usage detected during active task timer. Timer reset.',
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
          content: Text(taskTitle),
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
      await _storageService.saveProtocolViolation(
        type: 'willpower_weakness',
        severity: 'medium',
        source: 'app_flow',
        taskTitle: taskTitle,
        details: 'Task outcome marked as not completed by user.',
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
      final baseDelay = _resolveInitialTaskDelay(taskTitle);
      final delay = _disciplineProtocolService.computeAdaptiveTaskDuration(
        baseDuration: baseDelay,
        successRate: _currentSuccessRate(),
      );
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
      await _storageService.saveProtocolViolation(
        type: 'deferred_start',
        severity: 'medium',
        source: 'app_flow',
        taskTitle: taskTitle,
        details: 'User deferred task start for 10 minutes.',
      );
      final delay = const Duration(minutes: 10);
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
      await _storageService.saveProtocolViolation(
        type: 'followup_deferred',
        severity: 'low',
        source: 'app_flow',
        taskTitle: taskTitle,
        details: 'Follow-up response deferred for 10 minutes.',
      );
      final delay = const Duration(minutes: 10);
      final followUpAt = DateTime.now().add(delay);
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
    final initialRecord = await _storageService.loadSurveyHistory()
        .then((records) => records.where((r) => r.type == 'initial').firstOrNull);
    int smokeFreeDays = 0;
    if (initialRecord?.quitDate != null) {
      smokeFreeDays = DateTime.now().difference(initialRecord!.quitDate!).inDays;
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
    final pendingFollowUps = await _storageService.loadPendingTaskFollowUps();
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
      _progressSummaryText = behavior?.progressSummary ?? 'Stable';
      _todaysTasks = behavior?.todaysTasks ?? const [];
      _coachCommands = behavior?.coachCommands ?? const [];
      _durationBarrierCommands = behavior?.durationBarrierCommands ?? const [];
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
      for (final task in _todaysTasks) {
        _taskStates.putIfAbsent(task, () => 'new');
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
    }
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
        return 'Klinik degerlendirme onerilir';
      case 'monitor_closer':
        return 'Yakin izlem';
      default:
        return 'Stabil';
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
        return AlertDialog(
          title: const Text('Gunluk nefes testi gerekli'),
          content: const Text(
            'Gelişimi doğru takip etmek için her gün en az 1 profesyonel nefes testi yapılmalı. Şimdi testi başlatalım.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Testi Baslat'),
            ),
          ],
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
          return AlertDialog(
            title: const Text('Haftalik anket zorunlu'),
            content: const Text(
              'Risk skorunun guncel kalmasi icin en az 7 gunde bir haftalik anket doldurmalisin.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Ankete git'),
              ),
            ],
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
          ),
        ),
      );
      return;
    }

    if (_weeklySurveyPromptShownSession) {
      return;
    }

    final promptedToday = await _storageService.hasWeeklySurveyBeenPromptedToday();
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

  Future<void> _scheduleCoachCommandNotificationsIfNeeded() async {
    if (!_registrationCompleted || _coachCommands.isEmpty) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Komut tamamlandi olarak kaydedildi.')),
    );
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
            ? 'Sure bariyeri tamamlandi. Basarili oldun mu?'
            : '$minutes dakikalik sure bariyeri bitti. Basarili oldun mu?';
        return AlertDialog(
          title: const Text('Sure bariyeri degerlendirme'),
          content: Text(prompt),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Basarisiz'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Basarili'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return;
    }

    await _storageService.saveTaskResult(
      taskTitle: command,
      taskResult: result ? 'barrier_success' : 'barrier_failure',
      completedAt: DateTime.now(),
    );
    if (!result) {
      await _storageService.saveProtocolViolation(
        type: 'duration_barrier_failure',
        severity: 'medium',
        source: 'app_flow',
        taskTitle: command,
        details: 'User marked duration barrier as failed after timer end.',
      );
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result
              ? 'Sure bariyeri basarili kaydedildi. Sonraki bariyerler buna gore ayarlanacak.'
              : 'Sure bariyeri basarisiz kaydedildi. Sonraki bariyerler uyuma gore guncellenecek.',
        ),
      ),
    );
    await _loadHomeMetrics();
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
    ).showSnackBar(const SnackBar(content: Text('Komut 10 dakika ertelendi.')));
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sure bariyeri 10 dakika ertelendi.')),
    );
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

  Future<void> _presentMandatoryTaskIfNeeded() async {
    if (!mounted || _mandatoryTaskShown || !_registrationCompleted) {
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
    await _storageService.saveProtocolViolation(
      type: 'mandatory_gate',
      severity: 'medium',
      source: 'app_flow',
      taskTitle: taskTitle,
      details: 'Mandatory task screen displayed on app open.',
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
      await _startTaskFromMandatoryScreen(taskTitle!);
    }
  }

  Future<void> _startTaskFromMandatoryScreen(String taskTitle) async {
    final now = DateTime.now();
    final baseDelay = _resolveInitialTaskDelay(taskTitle);
    final delay = _disciplineProtocolService.computeAdaptiveTaskDuration(
      baseDuration: baseDelay,
      successRate: _currentSuccessRate(),
    );
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
    final hasInitialSurvey = records.any((record) => record.type == 'initial');
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
      final taskStartTitle = context.t('taskStartTitle');

      debugPrint('[CompleteRegistration] Creating first task: $firstTask');
      final createdAt = DateTime.now();
      const followUpDelay = Duration(minutes: 5);

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
        await NotificationService.showFirstTaskTriggerNotification(
          taskTitle: taskStartTitle,
          taskDescription: firstTask,
        );

        await NotificationService.scheduleFirstTaskTriggerNotification(
          taskDescription: firstTask,
          delay: const Duration(seconds: 30),
        );

        await NotificationService.scheduleFirstTaskTriggerNotification(
          taskDescription: firstTask,
          delay: followUpDelay,
        );
        debugPrint(
          '[CompleteRegistration] first task notification shown now + scheduled (30s, 5m)',
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
      _showRegistrationError(
        'Kaydı tamamlanırken bir hata oluştu. Lütfen tekrar deneyin.',
      );
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
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NoSmokeLogo(size: 28),
            const SizedBox(width: 10),
            Text(context.t('home')),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
              // Daily Streak Counter - Büyük ve göze çarpıcı
              Container(
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
                      _smokeFreeDays == 1 ? 'gün' : 'gün',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Health Metrics Button
              SizedBox(
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
              ),
              const SizedBox(height: 24),
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
              if (_pendingFollowUps.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TaskFollowUpPage(),
                        ),
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
              const SizedBox(height: 16),
              _buildConsecutiveSmokingCard(),
              const SizedBox(height: 24),
              if (!_registrationCompleted)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isCompletingRegistration
                        ? null
                        : _completeRegistration,
                    child: Text(context.t('completeRegistration')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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
              'Haftalik anket riski: $_weeklySurveyRiskScore/100 (${_weeklySurveyRiskLevel.toUpperCase()})',
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
                'Respiratuar durum: ${_respiratoryStateLabel()} • Yuk: $_lastRespiratoryBurden/100',
                style: TextStyle(
                  color: _respiratoryBandColor(),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_weeklyTopRiskDrivers.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Haftalik ust risk etkenleri: ${_weeklyTopRiskDrivers.join(' | ')}',
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Komut modu: '),
                _buildCommandMixBadge(_commandMixMode),
              ],
            ),
            if (_learnedWeights.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Ogrenilen agirliklar: ${_formatLearnedWeights(_learnedWeights)}',
              ),
            ],
            if (_coachCommands.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Kisisel komutlar',
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
                            child: const Text('Tamam'),
                          ),
                          TextButton(
                            onPressed: () => _deferCoachCommand(command),
                            child: const Text('Ertele 10 dk'),
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
              const Text(
                'Sure bariyerleri (ayri calisir)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
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
                            onPressed: () => _completeDurationBarrier(command),
                            child: const Text('Tamam'),
                          ),
                          TextButton(
                            onPressed: () => _deferDurationBarrier(command),
                            child: const Text('Ertele 10 dk'),
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
                'Komut basari puanlari: ${_formatCommandScores(_coachCommands, _commandSuccessScores)}',
              ),
            ],
            if (_commandCategoryScores.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Kategori basari icgorusu: ${_formatCategoryScores(_commandCategoryScores)}',
              ),
            ],
            if (_riskExplanation.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Risk skoru aciklamasi',
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

  Widget _buildMainMenuCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hizli menu',
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
                    label: const Text('Nefes Testi'),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: OutlinedButton.icon(
                    onPressed: _openWeeklySurveyFromMenu,
                    icon: const Icon(Icons.assignment),
                    label: const Text('Haftalik Anket'),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: OutlinedButton.icon(
                    onPressed: _openPersonalProgressScreen,
                    icon: const Icon(Icons.insights),
                    label: const Text('Kisisel Takip'),
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
                    label: const Text('Ihlal Raporu'),
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
            Text('Bildirim baglam nedeni: $_notificationContextReasonText'),
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
