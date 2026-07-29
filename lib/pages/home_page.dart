import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../core/app_texts.dart';
import '../core/app_theme.dart';
import '../models/adaptive_task_models.dart';
import '../models/mentor_message.dart';
import '../models/reduction_progress.dart';
import '../models/survey_record.dart';
import '../models/user_profile_snapshot.dart';
import '../pages/achievements_page.dart';
import '../pages/breath_test_page.dart';
import '../pages/craving_sos_page.dart';
import '../pages/smoked_log_consent_page.dart';
import '../pages/health_metrics_page.dart';
import '../pages/mandatory_task_page.dart';
import '../pages/personal_progress_page.dart';
import '../pages/protocol_violations_page.dart';
import '../pages/reports_page.dart';
import '../pages/settings_page.dart';
import '../pages/survey_history_page.dart';
import '../pages/task_follow_up_page.dart';
import '../pages/task_outcome_confirm_page.dart';
import '../pages/weekly_survey_page.dart';
import '../services/device_permission_service.dart';
import '../services/discipline_protocol_service.dart';
import '../services/location_intelligence_service.dart';
import '../services/step_tracking_service.dart';
import '../services/notification_service.dart';
import '../services/protocol_violation_service.dart';
import '../services/breath_test_gate.dart';
import '../services/smoked_log_button_service.dart';
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
  Timer? _mandatoryPostponeRetryTimer;
  int _mandatoryTaskPostponeCount = 0;
  List<Map<String, dynamic>> _pendingFollowUps = const [];
  bool _mandatoryTaskShown = false;
  bool _followUpConfirmShown = false;
  bool _weeklySurveyMandatoryShown = false;
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
  List<AdaptiveTaskPlanItem> _adaptivePlanItems = const [];
  List<String> _coachCommands = const [];
  List<String> _durationBarrierCommands = const [];
  int _weeklySurveyRiskScore = 40;
  String _weeklySurveyRiskLevel = 'medium';
  List<String> _riskExplanation = const [];
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
  ReductionProgress? _reductionProgress;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_handlePendingQuickLogRoute());
      unawaited(_offerQuickLogButtonOnce());
    });
  }

  /// Opens whatever the floating button's menu asked for while the app was
  /// closed.
  ///
  /// The menu runs in a native overlay with no Flutter engine behind it, so
  /// choosing "SOS" there can only leave a note and start the activity — the
  /// same queue-and-drain shape every other native→Dart path here uses.
  /// Without this the user picked SOS mid-craving and landed on the
  /// dashboard.
  Future<void> _handlePendingQuickLogRoute() async {
    final route = await SmokedLogButtonService().drainPendingRoute();
    if (route != SmokedLogButtonService.routeSos || !mounted) {
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CravingSosPage()));
  }

  /// Offers the floating "I smoked" button to someone who was already set up
  /// before it existed.
  ///
  /// Setup offers it now, but that flow only runs once and never again for
  /// an existing install — so everyone who had the app before the button
  /// shipped would only ever find it by scrolling through settings. It is
  /// the app's only source of ground truth about when the user actually
  /// smokes, which is what the barrier length and the risky-hour ranking are
  /// both computed from, so leaving it undiscovered costs the programme its
  /// aim.
  ///
  /// Asked once. Declining is remembered and nothing asks again.
  Future<void> _offerQuickLogButtonOnce() async {
    if (!mounted) return;
    await offerSmokedLogButton(context);
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
    _mandatoryPostponeRetryTimer?.cancel();
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
      final delay = await _askPostponeDelay();
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

  /// Instead of silently picking a postpone delay for the user, ask them
  /// directly when they want to be reminded -- if they don't answer within
  /// [_postponePromptTimeout], the dialog auto-answers with the same 5
  /// minute default the unanswered-task retry chain already uses
  /// (NotificationService._unansweredReminderDelay), so a user who just
  /// doesn't respond gets the same cadence either way.
  static const Duration _postponePromptTimeout = Duration(minutes: 5);

  Future<Duration> _askPostponeDelay() async {
    if (!mounted) {
      return _postponePromptTimeout;
    }
    final options = <Duration>[
      const Duration(minutes: 5),
      const Duration(minutes: 15),
      const Duration(minutes: 30),
      const Duration(hours: 1),
    ];

    Timer? autoAnswerTimer;
    final result = await showDialog<Duration>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        autoAnswerTimer = Timer(_postponePromptTimeout, () {
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop(_postponePromptTimeout);
          }
        });
        return AlertDialog(
          title: Text(context.t('postponeReminderPromptTitle')),
          content: Text(context.t('postponeReminderPromptMessage')),
          actions: options
              .map(
                (option) => TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(option),
                  child: Text(_formatPostponeOptionLabel(option)),
                ),
              )
              .toList(),
        );
      },
    );
    autoAnswerTimer?.cancel();
    return result ?? _postponePromptTimeout;
  }

  String _formatPostponeOptionLabel(Duration option) {
    if (option.inHours >= 1) {
      return context.t('oneHourLabel');
    }
    return '${option.inMinutes} ${context.t('minutesShort')}';
  }

  /// Pushes the current snapshot to the home-screen widget (see
  /// android/.../NoSmokeWidgetProvider.kt, which only ever reads this data
  /// back — it never talks to the database directly) and asks Android to
  /// redraw it. Safe to call every time metrics reload since HomeWidget's
  /// underlying SharedPreferences write is cheap and idempotent.
  Future<void> _updateHomeScreenWidget() async {
    if (!mounted) {
      return;
    }
    final streakLabel = context.t('reductionStreakLabel');
    final riskLabel = '${context.t('riskLevel')}: $_adaptiveRiskScore/100';
    try {
      await HomeWidget.saveWidgetData<int>(
        'reductionStreakDays',
        _reductionProgress?.targetStreakDays ?? 0,
      );
      await HomeWidget.saveWidgetData<String>(
        'reductionStreakLabel',
        streakLabel,
      );
      await HomeWidget.saveWidgetData<String>('breathScoreLabel', riskLabel);
      await HomeWidget.updateWidget(
        androidName: 'NoSmokeWidgetProvider',
        qualifiedAndroidName: 'com.example.no_smoke.NoSmokeWidgetProvider',
      );
    } catch (_) {
      // Best-effort only — the widget is a convenience surface, never a
      // dependency for the rest of the app to keep working.
    }
  }

  Future<void> _loadHomeMetrics() async {
    // Was `now - quitDate`, which counted days the user had smoked on. The
    // reduction figures are derived from logged cigarettes and answered
    // tasks instead, so a day only counts when something actually happened.
    final reductionProgress = await _storageService.loadReductionProgress();

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
      _reductionProgress = reductionProgress;
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
      _adaptivePlanItems = adaptivePlan?.items ?? const [];
      _todaysTasks = _adaptivePlanItems.isNotEmpty
          ? _adaptivePlanItems.map((item) => item.taskTitle).toList()
          : behavior?.todaysTasks ?? const [];
      _coachCommands = behavior?.coachCommands ?? const [];
      _durationBarrierCommands = behavior?.durationBarrierCommands ?? const [];
      _durationBarrierHistoryCount = behavior?.durationBarrierHistoryCount ?? 0;
      _weeklySurveyRiskScore = behavior?.weeklySurveyRiskScore ?? 40;
      _weeklySurveyRiskLevel = behavior?.weeklySurveyRiskLevel ?? 'medium';
      _riskExplanation = behavior?.riskExplanation ?? const [];
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
    unawaited(_updateHomeScreenWidget());

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
      unawaited(_presentPendingFollowUpIfNeeded());
      unawaited(_presentMandatoryTaskIfNeeded());
      unawaited(_storageService.refreshWearableRiskSignal());
      unawaited(_scheduleSedentaryReminderIfNeeded());
      await _ensureMentorMessageCadence();
    }
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
    // Elapsed time since the last reading, not "is there one dated today".
    // Someone who tested at 23:50 and opens the app at 00:10 has skipped
    // nothing, and being handed an un-dismissable prompt twenty minutes
    // later would read as the app losing track.
    const gate = BreathTestGate();
    final now = DateTime.now();
    final lastAt = (await _storageService.loadLatestBreathRecord())
        ?.completedAt;
    if (!gate.shouldPrompt(lastCompletedAt: lastAt, now: now)) {
      return;
    }
    final mayDefer = gate.canDefer(lastCompletedAt: lastAt, now: now);
    if (!mayDefer) {
      // Also say it outside the app. Someone who dismisses the task by
      // closing the app has no other way of learning the reading is missing
      // until they next open it — which is precisely the loop that lets a
      // day go by unmeasured.
      unawaited(NotificationService.showBreathTestOverdueNotification());
    }
    if (!mounted) return;
    _dailyBreathMandatoryShownSession = true;

    final startNow = await showDialog<bool>(
      context: context,
      barrierDismissible: mayDefer,
      builder: (dialogContext) {
        // canPop follows the same rule as the "later" button. Blocking
        // tap-outside is not enough on its own: the Android system/gesture
        // back button would otherwise dismiss the prompt for free, which is
        // how the previous version could be skipped without answering.
        return PopScope(
          canPop: mayDefer,
          child: AlertDialog(
            title: Text(context.t('dailyBreathMandatoryTitle')),
            content: Text(
              mayDefer
                  ? context.t('dailyBreathPromptContent')
                  // A full day with no reading leaves a hole in the trend
                  // that cannot be filled in afterwards, so this wording
                  // says why there is no way out rather than just removing
                  // the button.
                  : context.t('dailyBreathOverdueContent'),
            ),
            actions: [
              if (mayDefer)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(context.t('dailyBreathLater')),
                ),
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

    // Straight into the breath test. This used to go through a daily
    // check-in page that paired it with a "which hours did you smoke today?"
    // recall survey; the quick-log button records those moments as they
    // happen, so asking the user to reconstruct them at day's end was both
    // less accurate and an extra screen in the way.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BreathTestPage(name: widget.name, packsPerDay: packsPerDay),
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
    // No separate "would you like to fill it out now?" nudge below this
    // point on purpose: it used to fire once a day regardless of how
    // recently the survey had actually been completed, so it was asking
    // within the very first days after onboarding — before the weekly
    // survey could possibly be due yet. The `overdue` branch above is the
    // only place this gate belongs; it already covers "ask (and, once
    // truly overdue, require) on a later app open."
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

  int? _extractDurationBarrierMinutes(String command) {
    // Adaptive duration-barrier commands are the canonical
    // 'ADAPTIVE_NO_SMOKE:<minutes>' code (see DisciplineProtocolService),
    // not display text -- the older 'Sonraki N dakika' pattern this used
    // to match hasn't existed since that canonical-code refactor, so it
    // always silently returned null.
    final canonicalMatch = RegExp(
      r'^ADAPTIVE_NO_SMOKE:(\d+)$',
      caseSensitive: false,
    ).firstMatch(command.trim());
    if (canonicalMatch != null) {
      return int.tryParse(canonicalMatch.group(1) ?? '');
    }
    final legacyMatch = RegExp(
      r'Sonraki\s+(\d+)\s+dakika',
      caseSensitive: false,
    ).firstMatch(command);
    if (legacyMatch == null) {
      return null;
    }
    return int.tryParse(legacyMatch.group(1) ?? '');
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
  // How long to wait before retrying the mandatory-gate check after finding
  // the user on a genuine phone call.
  static const Duration _phoneCallRetryDelay = Duration(minutes: 15);
  // The point of this gate is to actually keep the user from smoking during
  // the target window — tapping "Ertele" (postpone) can't just make it go
  // away, so it comes back after a short delay instead of waiting out the
  // full cooldown, for at least this many attempts per day.
  static const Duration _mandatoryPostponeRetryDelay = Duration(minutes: 10);
  static const int _maxMandatoryPostponeRetries = 5;

  /// Forces an answer for the oldest due follow-up (its scheduledAt has
  /// already passed) via [TaskOutcomeConfirmPage] — replaces relying on an
  /// in-memory Timer ([_scheduleLocalFollowUp]/`_askTaskOutcome`), which
  /// only ever fires while this exact widget instance stays alive in
  /// memory (so it silently never asks once the app is backgrounded long
  /// enough to be suspended, which is the common case for delays of tens
  /// of minutes), and the notification action buttons, which are easy to
  /// swipe away without answering. Runs before [_presentMandatoryTaskIfNeeded]
  /// in the app-open cadence so an overdue follow-up is resolved before any
  /// new task gets presented.
  Future<void> _presentPendingFollowUpIfNeeded() async {
    if (!mounted || _followUpConfirmShown || !_registrationCompleted) {
      return;
    }

    final now = DateTime.now();
    Map<String, dynamic>? due;
    for (final row in _pendingFollowUps) {
      final scheduledAt = row['scheduledAt'] as DateTime?;
      if (scheduledAt == null || !scheduledAt.isAfter(now)) {
        due = row;
        break;
      }
    }
    if (due == null) {
      return;
    }

    final id = due['id'] as String?;
    final taskTitle = due['taskTitle'] as String?;
    if (id == null || taskTitle == null || taskTitle.trim().isEmpty) {
      return;
    }
    final scheduledAt = due['scheduledAt'] as DateTime?;

    _followUpConfirmShown = true;
    final succeeded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskOutcomeConfirmPage(taskTitle: taskTitle),
      ),
    );
    _followUpConfirmShown = false;

    if (succeeded != true) {
      await _protocolViolationService.logFollowUpFailed(taskTitle: taskTitle);
    }

    final plannedMinutes = _resolveInitialTaskDelay(taskTitle).inMinutes;
    await _storageService.recordAdaptiveTaskOutcome(
      taskTitle: taskTitle,
      outcome: succeeded == true
          ? AdaptiveTaskOutcome.success
          : AdaptiveTaskOutcome.smoked,
      plannedDurationMinutes: plannedMinutes,
      scheduledAt: scheduledAt,
      respondedAt: DateTime.now(),
    );
    await _storageService.saveTaskResult(
      taskTitle: taskTitle,
      taskResult: succeeded == true ? 'willpower_success' : 'willpower_weakness',
      completedAt: DateTime.now(),
    );
    await _storageService.resolveTaskFollowUpById(id);
    _taskFollowUpTimers[taskTitle]?.cancel();
    _taskFollowUpTimers.remove(taskTitle);

    if (!mounted) {
      return;
    }
    setState(() {
      _taskStates[taskTitle] = succeeded == true ? 'completed' : 'failed';
    });

    await _loadHomeMetrics();
    await _restorePendingFollowUps();

    // Chain through any further overdue follow-ups one at a time, instead
    // of only ever resolving one per app open.
    unawaited(_presentPendingFollowUpIfNeeded());
  }

  Future<void> _presentMandatoryTaskIfNeeded({bool isRetry = false}) async {
    if (!mounted || (!isRetry && _mandatoryTaskShown) || !_registrationCompleted) {
      return;
    }

    if (!isRetry) {
      final lastShownAt = await _storageService.loadLastMandatoryGateShownAt();
      if (lastShownAt != null &&
          DateTime.now().difference(lastShownAt) < _mandatoryGateCooldown) {
        return;
      }
    }

    // Don't interrupt a genuine phone call with the mandatory-command
    // screen. This is a one-shot check at present-time, not a live
    // listener, so it retries once after the same delay rather than trying
    // to catch the exact moment the call ends.
    if (await DevicePermissionService.isInPhoneCall()) {
      _mandatoryGateCallRetryTimer?.cancel();
      _mandatoryGateCallRetryTimer = Timer(
        _phoneCallRetryDelay,
        () => unawaited(_presentMandatoryTaskIfNeeded()),
      );
      return;
    }

    // Due follow-ups are handled by _presentPendingFollowUpIfNeeded (asks
    // "did it succeed", not "start this task") — only genuinely new tasks
    // reach this gate.
    String? taskTitle;
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
      _mandatoryTaskPostponeCount = 0;
      await _startTaskFromMandatoryScreen(taskTitle);
      return;
    }

    if (_mandatoryTaskPostponeCount < _maxMandatoryPostponeRetries) {
      _mandatoryTaskPostponeCount++;
      _mandatoryTaskShown = false;
      _mandatoryPostponeRetryTimer?.cancel();
      _mandatoryPostponeRetryTimer = Timer(
        _mandatoryPostponeRetryDelay,
        () => unawaited(_presentMandatoryTaskIfNeeded(isRetry: true)),
      );
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

  /// How late a planned task may be and still be worth firing. Past this the
  /// real-world window it was aimed at is gone, so it is closed out as missed
  /// rather than delivered late (see the overdue branch in [_notifyNewTasks]).
  static const Duration _overdueTaskGrace = Duration(minutes: 15);

  Future<void> _notifyNewTasks() async {
    if (_todaysTasks.isEmpty) {
      return;
    }

    // Persisted, not just in-memory: `_notifiedTaskTitles` alone forgot
    // what had already been notified every time the process restarted
    // (very common — OEM battery killers, normal app-switching), so every
    // reopen re-scheduled a fresh notification for every task still 'new',
    // stacking duplicates on top of whatever was already pending from
    // earlier that day. See StorageService.loadNotifiedTaskTitlesToday.
    final notifiedToday = await _storageService.loadNotifiedTaskTitlesToday();
    _notifiedTaskTitles.addAll(notifiedToday);

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
        if (delay <= -_overdueTaskGrace) {
          // The moment this task was tied to has already passed — firing it
          // now would just be catch-up spam with no therapeutic value, and
          // reopening the app after a few hours away would dump every task
          // the user was away for onto them at once. Close it out as missed
          // instead so the learning engine still hears about it.
          await _storageService.recordAdaptiveTaskOutcome(
            taskTitle: task,
            outcome: AdaptiveTaskOutcome.missed,
            plannedDurationMinutes: item.durationMinutes,
            scheduledAt: item.scheduledAt,
          );
          _notifiedTaskTitles.add(task);
          await _storageService.markTaskTitleNotifiedToday(task);
          continue;
        }
        if (delay.inSeconds <= 0) {
          // Only just missed (still inside the grace window) — worth firing.
          delay = const Duration(minutes: 1);
        }

        await NotificationService.scheduleFirstTaskTriggerNotification(
          taskDescription: task,
          delay: delay,
        );

        _notifiedTaskTitles.add(task);
        await _storageService.markTaskTitleNotifiedToday(task);
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

    // No second scheduler beyond this point.
    //
    // There used to be a fallback here that fired whenever the adaptive plan
    // was empty, spacing tasks as `base + index * gap` measured from the
    // moment the app happened to be open. That is not a time of day — it is
    // an offset from install, so a user who finished setup at nine in the
    // evening had their whole day's tasks stacked into the next hour and a
    // half, one after another. It also produced titles the learning engine
    // cannot score: only `ADAPTIVE_NO_SMOKE:n` is recognised, so nothing
    // those tasks did ever reached the barrier review.
    //
    // The plan is the schedule. When it comes back empty the honest answer
    // is no tasks — either setup isn't finished, or the remaining part of
    // today genuinely has no room left for a barrier-length commitment.
    // Registration still starts the first one on its own.
  }

  static const Duration _sedentaryReminderCooldown = Duration(hours: 3);

  /// Phase 11: a gentle "you've been still for a while" nudge, reusing the
  /// step data already collected for reports (no new sensor/permission).
  /// Gated by waking hours (hour-granularity is enough for this — it's a
  /// wellness suggestion, not a precise scheduler) and a cooldown so it
  /// can fire more than once a day without turning into the same
  /// duplicate-notification problem `_notifyNewTasks` had.
  Future<void> _scheduleSedentaryReminderIfNeeded() async {
    if (!_registrationCompleted) {
      return;
    }

    final now = DateTime.now();
    final sleepRaw = await _storageService.loadSleepTime() ?? '23:00';
    final wakeRaw = await _storageService.loadSetting('wake_time') ?? '07:00';
    final sleepHour = int.tryParse(sleepRaw.split(':').first) ?? 23;
    final wakeHour = int.tryParse(wakeRaw.split(':').first) ?? 7;
    final withinWakingHours = wakeHour <= sleepHour
        ? now.hour >= wakeHour && now.hour < sleepHour
        : now.hour >= wakeHour || now.hour < sleepHour;
    if (!withinWakingHours) {
      return;
    }

    final lastRaw = await _storageService.loadSetting(
      'last_sedentary_reminder_at',
    );
    final last = lastRaw != null ? DateTime.tryParse(lastRaw) : null;
    if (last != null && now.difference(last) < _sedentaryReminderCooldown) {
      return;
    }

    if (!await _storageService.isRecentlySedentary()) {
      return;
    }

    await NotificationService.showSedentaryReminderNotification();
    await _storageService.saveSetting(
      'last_sedentary_reminder_at',
      now.toIso8601String(),
    );
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
      }
      // With no plan there is no next task, so there is no time to show.
      // This branch used to compute one from the same `index * gap` offset
      // the retired fallback scheduler used, which meant the card announced
      // a task that nothing was going to deliver.
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
      // No task at the finish line of setup.
      //
      // Registration used to create one and fire it ten minutes later. The
      // user had just spent five screens answering questions; being handed a
      // full-screen command straight afterwards reads as nagging, and it
      // arrives before the barrier has been seeded from those answers, so it
      // is not even the right length. The daily plan schedules the first real
      // task at a time of day that suits the person, which is the whole point
      // of having asked.

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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
              _buildReductionCard(context),
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
        // Pinned in the app bar (not a floating button) so it stays visible
        // at the top no matter how far the page is scrolled, rather than
        // floating over — and sometimes obscuring — page content.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextButton.icon(
            key: const ValueKey('craving_sos_button'),
            onPressed: _openCravingSos,
            style: TextButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            icon: const Icon(Icons.sos, size: 18),
            label: Text(context.t('cravingSosButton')),
          ),
        ),
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
      'coach' => AppTheme.brandPrimary,
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

  /// Replaces a counter that showed calendar days since the quit date and
  /// never checked whether the user had smoked. This app asks people to cut
  /// down, not to stop outright, so an abstinence streak measured nothing
  /// they were being asked to do — and it went up on days they smoked.
  Widget _buildReductionCard(BuildContext context) {
    final progress = _reductionProgress;
    const accent = Colors.teal;

    return InkWell(
      // The badge grid had no entry point anywhere in the app — it was
      // written, then never linked. The card showing the figures badges are
      // awarded on is the natural place to reach it from.
      borderRadius: BorderRadius.circular(12),
      onTap: progress == null
          ? null
          : () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AchievementsPage(progress: progress),
                ),
              );
            },
      child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent.withAlpha((255 * 0.2).toInt()),
        border: Border.all(color: accent, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '📉 ${context.t('reductionCardTitle')}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
          const SizedBox(height: 16),
          if (progress == null || !progress.hasEvidence) ...[
            // Three confident zeros would read as failure to someone who has
            // simply just installed the app. Say what's missing instead.
            Text(
              context.t('reductionNoDataTitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.t('reductionNoDataBody'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: accent.withAlpha((255 * 0.85).toInt()),
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildReductionMetric(
                    context,
                    value: '${progress.targetStreakDays}',
                    unit: context.t('dayUnit'),
                    label: context.t('reductionStreakLabel'),
                  ),
                ),
                Expanded(
                  child: _buildReductionMetric(
                    context,
                    value: '${progress.cigarettesAvoided}',
                    unit: context.t('cigaretteUnit'),
                    label: context.t('reductionAvoidedLabel'),
                  ),
                ),
                Expanded(
                  child: _buildReductionMetric(
                    context,
                    value: '${progress.currentBarrierMinutes}',
                    unit: context.t('minutesShort'),
                    label: context.t('reductionIntervalLabel'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              context
                  .t('reductionTargetToday')
                  .replaceAll('{target}', '${progress.dailyTarget}'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
            if (progress.loggedToday != null)
              Text(
                context
                    .t('reductionLoggedToday')
                    .replaceAll('{count}', '${progress.loggedToday}'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: accent.withAlpha((255 * 0.85).toInt()),
                ),
              ),
            if (progress.naturalIntervalMinutes > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${context.t('reductionIntervalDetail').replaceAll('{natural}', '${progress.naturalIntervalMinutes}').replaceAll('{barrier}', '${progress.currentBarrierMinutes}')}'
                ' • '
                '${context.t('reductionIntervalGain').replaceAll('{percent}', '${(progress.intervalProgress * 100).round()}')}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: accent.withAlpha((255 * 0.85).toInt()),
                ),
              ),
            ],
          ],
        ],
      ),
      ),
    );
  }

  Widget _buildReductionMetric(
    BuildContext context, {
    required String value,
    required String unit,
    required String label,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        Text(
          unit,
          style: const TextStyle(fontSize: 12, color: Colors.teal),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            height: 1.25,
            color: Colors.teal.withAlpha((255 * 0.9).toInt()),
          ),
        ),
      ],
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
            const SizedBox(height: 6),
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
                // "Sigara İçtim" and "Günlük Değerlendirme" used to sit here.
                // The first is being replaced by the always-available
                // quick-log button, which reaches further than a menu entry
                // the user has to open the app to find; the second asked at
                // day's end which hours they had smoked, which that same
                // button now records as it happens.
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
                _buildTrendBar(
                  context.t('daily'),
                  values[0],
                  _dailyAverage,
                  _calculateImprovementLabel(_dailyAverage, _weeklyAverage),
                ),
                _buildTrendBar(
                  context.t('weekly'),
                  values[1],
                  _weeklyAverage,
                  _weeklyImprovementText,
                ),
                _buildTrendBar(
                  context.t('monthly'),
                  values[2],
                  _monthlyAverage,
                  _monthlyImprovementText,
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

  Widget _buildTrendBar(
    String label,
    double ratio,
    double value,
    String trendKey,
  ) {
    final trendIcon = trendKey == 'trendImproving'
        ? Icons.trending_up
        : trendKey == 'trendDeclining'
        ? Icons.trending_down
        : Icons.trending_flat;
    final trendColor = trendKey == 'trendImproving'
        ? Colors.greenAccent
        : trendKey == 'trendDeclining'
        ? Colors.redAccent
        : Colors.white70;

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
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  FractionallySizedBox(
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
                  // A breath icon + trend arrow gives an at-a-glance read of
                  // "getting better/worse/steady" without reading the caption
                  // text below, on top of the number the bar already shows.
                  Positioned(
                    top: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.air, size: 14, color: Colors.white70),
                        const SizedBox(width: 2),
                        Icon(trendIcon, size: 14, color: trendColor),
                      ],
                    ),
                  ),
                  // Otherwise a full/near-full bar is just a solid block of
                  // colour with nothing on it — the number belongs on the
                  // bar itself, not only in the caption text below.
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      value.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                ],
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
}
