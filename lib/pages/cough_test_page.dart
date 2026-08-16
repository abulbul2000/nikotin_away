import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../engines/cough_acoustic_engine.dart';
import '../engines/wheeze_detection_engine.dart';
import '../models/breath_acoustic_sample.dart';
import '../models/cough_test_record.dart';
import '../models/wheeze_acoustic_sample.dart';
import '../models/noise_check_result.dart';
import '../services/behavior_engine.dart';
import '../services/breath_audio_service.dart';
import '../services/breath_noise_check_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../widgets/success_check_overlay.dart';

enum _CoughTestPhase { notStarted, listening, finished }

/// A short (10s), user-initiated test that listens for acoustic
/// wheeze patterns while the user coughs several times.

class CoughTestPage extends StatefulWidget {
  final bool navigateToHomeOnComplete;

  /// Called after a test completes and its result is saved — used by
  /// WeeklySurveyPage's save-flow check to know the requirement was met
  /// without re-querying storage itself.
  final VoidCallback? onCompleted;

  /// When set, the "devam" button on the result screen calls this instead of
  /// popping the page — used by SleepRoutinePage, which embeds this page as
  /// one step of a larger flow and needs to advance to the next step rather
  /// than close.
  final VoidCallback? onFinishRequested;
  final BreathAudioService? breathAudioService;
  final CoughAcousticEngine? coughAcousticEngine;
  final StorageService? storageService;
  final BreathNoiseCheckService? breathNoiseCheckService;

  const CoughTestPage({
    super.key,
    this.navigateToHomeOnComplete = false,
    this.onCompleted,
    this.onFinishRequested,
    this.breathAudioService,
    this.coughAcousticEngine,
    this.storageService,
    this.breathNoiseCheckService,
  });

  @override
  State<CoughTestPage> createState() => _CoughTestPageState();
}

class _CoughTestPageState extends State<CoughTestPage> {
  static const int _testDurationSeconds = 10;

  late final BreathAudioService _audioService;
  late final CoughAcousticEngine _acousticEngine;
  late final StorageService _storageService;
  late final BehaviorEngine _behaviorEngine;
  late final BreathNoiseCheckService _breathNoiseCheckService;

  _CoughTestPhase _phase = _CoughTestPhase.notStarted;
  int _secondsRemaining = _testDurationSeconds;
  Timer? _countdownTimer;
  final List<BreathAcousticSample> _samples = [];
  bool _micPermissionRequested = false;
  final WheezeDetectionEngine _wheezeDetectionEngine = WheezeDetectionEngine();
  final List<WheezeAcousticSample> _wheezeSamples = [];

  CoughTestRecord? _result;

  String? _wheezeAdvisoryTier;

  @override
  void initState() {
    super.initState();
    _audioService = widget.breathAudioService ?? BreathAudioService();
    _acousticEngine = widget.coughAcousticEngine ?? CoughAcousticEngine();
    _storageService = widget.storageService ?? StorageService();
    _behaviorEngine = BehaviorEngine();
    _breathNoiseCheckService =
        widget.breathNoiseCheckService ?? BreathNoiseCheckService();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _audioService.stopListening();
    super.dispose();
  }

  Future<void> _ensureMicrophonePermissionWithRationale() async {
    if (_micPermissionRequested) {
      return;
    }
    _micPermissionRequested = true;
    if (await _audioService.hasPermission()) {
      return;
    }
    if (!mounted) {
      return;
    }
    final wantsToGrant = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('micRationaleTitle')),
        content: Text(context.t('micRationaleMessage')),
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
    if (wantsToGrant == true) {
      await PermissionService.ensureMicrophonePermission();
    }
  }

  Future<void> _startTest() async {
    await _ensureMicrophonePermissionWithRationale();
    if (!mounted) {
      return;
    }
    _samples.clear();
    _wheezeSamples.clear();
    setState(() {
      _phase = _CoughTestPhase.listening;
      _secondsRemaining = _testDurationSeconds;
    });

    await _audioService.startListening(
      (sample) {
        _samples.add(sample);
      },
      onRawChunk: (chunk, elapsedMs) {
        final sample = _wheezeDetectionEngine.pushChunk(chunk, elapsedMs);
        if (sample != null) {
          _wheezeSamples.add(sample);
        }
      },
    );

    // No separate "sit-relax" step here (unlike BreathTestPage) — the test
    // is a single 10s listen, so the ambient check runs against whatever
    // was captured in the first 1.5s of that same window, before the user
    // has had time to cough.
    Timer(const Duration(milliseconds: 1500), () {
      unawaited(_runAmbientNoiseCheck());
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining -= 1;
      });
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _finishTest();
      }
    });
  }

  /// Checks the first ~1.5s of the recording against this device's own
  /// ambient-noise reference — same BreathNoiseCheckService this page's mic
  /// session shares the underlying audio pipeline with, just triggered once
  /// early in the listen window rather than during a dedicated sit-relax
  /// step (this test has none). Never blocks: "tekrar dene" simply restarts
  /// the whole 30s listen, "yine de devam et" leaves the countdown running
  /// exactly where it was.
  Future<void> _runAmbientNoiseCheck() async {
    if (!mounted || _phase != _CoughTestPhase.listening) {
      return;
    }
    if (_samples.isEmpty) {
      return;
    }
    final result = await _breathNoiseCheckService.evaluatePreTestSamples(
      List.of(_samples),
    );
    if (!mounted || _phase != _CoughTestPhase.listening) {
      return;
    }
    if (result.level == NoiseLevel.quiet) {
      return;
    }

    final keepGoing = await _showNoiseWarningDialog(result);
    if (!mounted || _phase != _CoughTestPhase.listening) {
      return;
    }
    if (keepGoing == false) {
      _countdownTimer?.cancel();
      unawaited(_audioService.stopListening());
      unawaited(_startTest());
    }
  }

  Future<bool?> _showNoiseWarningDialog(NoiseCheckResult result) {
    final isLoud = result.level == NoiseLevel.loud;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.t(
            isLoud ? 'breathNoiseLoudTitle' : 'breathNoiseWarningTitle',
          ),
        ),
        content: Text(
          context.t(
            isLoud ? 'breathNoiseLoudMessage' : 'breathNoiseWarningMessage',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t('breathNoiseRetry')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.t('breathNoiseContinueAnyway')),
          ),
        ],
      ),
    );
  }

  Future<void> _finishTest() async {
    await _audioService.stopListening();
    final analysis = _acousticEngine.analyze(
      _samples,
      testDurationSeconds: _testDurationSeconds,
    );

    if (mounted) {
      await SuccessCheckOverlay.show(context);
    }
    if (!mounted) {
      return;
    }

    final wheezeAnalysis = _wheezeDetectionEngine.analyze(_wheezeSamples);
    final record = CoughTestRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      coughCount: analysis.coughCount,
      testDurationSeconds: _testDurationSeconds,
      severityScore: analysis.severityScore,
      severityLevel: analysis.severityLevel,
      averageIntervalSeconds: analysis.averageIntervalSeconds,
      earlyBurstRatio: analysis.earlyBurstRatio,
      peakIntensityScore: analysis.peakIntensityScore,
      wheezeDetected: wheezeAnalysis.wheezeDetected,
      wheezeSeverityLevel: wheezeAnalysis.severityLevel,
      wheezeSeverityScore: wheezeAnalysis.severityScore,
      wheezeBandEnergyRatio: wheezeAnalysis.wheezeBandEnergyRatio,
    );
    await _storageService.saveCoughTestRecord(record);

    final healthConditions = await _storageService.loadHealthConditions();
    final priorRecords = await _storageService.loadCoughTestRecords(limit: 30);
    final fourteenDaysAgo = DateTime.now().subtract(const Duration(days: 14));

    String? wheezeAdvisoryTier;
    if (record.wheezeDetected == true) {
      const wheezeModerateOrWorse = {'moderate', 'severe'};
      final recentWheezeModerateOrWorseCount = priorRecords
          .where((r) => r.createdAt.isAfter(fourteenDaysAgo))
          .where(
            (r) =>
                r.wheezeSeverityLevel != null &&
                wheezeModerateOrWorse.contains(r.wheezeSeverityLevel),
          )
          .length;
      wheezeAdvisoryTier = _behaviorEngine.resolveWheezeAdvisoryTier(
        latestWheezeSeverityLevel: record.wheezeSeverityLevel!,
        healthConditions: healthConditions,
        recentModerateOrWorseCountLast14Days: recentWheezeModerateOrWorseCount,
      );
    }

    unawaited(
      NotificationService.showWheezeTestResultAdvisory(
        wheezeDetected: record.wheezeDetected == true,
        severityLevel: wheezeAdvisoryTier ?? 'normal',
      ),
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _result = record;
      _wheezeAdvisoryTier = wheezeAdvisoryTier;
      _phase = _CoughTestPhase.finished;
    });
    widget.onCompleted?.call();
  }

  void _finish() {
    if (widget.onFinishRequested != null) {
      widget.onFinishRequested!();
      return;
    }
    if (widget.navigateToHomeOnComplete) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.of(context).pop(_result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('coughTestTitle'))),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: _buildBody(context),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_phase) {
      case _CoughTestPhase.notStarted:
        return _buildNotStarted(context);
      case _CoughTestPhase.listening:
        return _buildListening(context);
      case _CoughTestPhase.finished:
        return _buildFinished(context);
    }
  }

  Widget _buildNotStarted(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.sick_outlined, size: 72),
        const SizedBox(height: 20),
        Text(
          context.t('coughTestIntro'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 12),
        Text(
          context.t('coughTestInstructions'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _startTest,
            child: Text(context.t('coughTestStartButton')),
          ),
        ),
      ],
    );
  }

  Widget _buildListening(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 1 - (_secondsRemaining / _testDurationSeconds),
                strokeWidth: 6,
              ),
              Text(
                '$_secondsRemaining',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          context.t('coughTestListening'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildFinished(BuildContext context) {
    final result = _result;
    if (result == null) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Text(
          context.t('coughTestResultTitle'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          result.wheezeDetected == true
              ? context.t('wheezeDetectedResult')
              : context.t('wheezeNotDetectedResult'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),

        if (result.wheezeDetected == true) ...[
          const SizedBox(height: 16),
          Card(
            key: const ValueKey('cough_result_wheeze_card'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('wheezeFindingSectionTitle'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(context.t('breathUnusualSoundDetected')),
                  if (_wheezeAdvisoryTier != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      context.t('breathUnusualSoundAdvice'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _finish,
            child: Text(context.t('continue')),
          ),
        ),
      ],
    );
  }
}
