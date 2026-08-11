import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../engines/cough_acoustic_engine.dart';
import '../models/breath_acoustic_sample.dart';
import '../models/cough_test_record.dart';
import '../services/behavior_engine.dart';
import '../services/breath_audio_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';

enum _CoughTestPhase { notStarted, listening, finished }

/// A short (default 30s), user-initiated test that counts distinct cough
/// events from the microphone — separate from BreathTestPage's multi-step
/// hold/exhale protocol, since this only needs to listen once and count,
/// not walk through a guided breathing sequence.
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

  const CoughTestPage({
    super.key,
    this.navigateToHomeOnComplete = false,
    this.onCompleted,
    this.onFinishRequested,
    this.breathAudioService,
    this.coughAcousticEngine,
    this.storageService,
  });

  @override
  State<CoughTestPage> createState() => _CoughTestPageState();
}

class _CoughTestPageState extends State<CoughTestPage> {
  static const int _testDurationSeconds = 30;

  late final BreathAudioService _audioService;
  late final CoughAcousticEngine _acousticEngine;
  late final StorageService _storageService;
  late final BehaviorEngine _behaviorEngine;

  _CoughTestPhase _phase = _CoughTestPhase.notStarted;
  int _secondsRemaining = _testDurationSeconds;
  Timer? _countdownTimer;
  final List<BreathAcousticSample> _samples = [];
  bool _micPermissionRequested = false;

  CoughTestRecord? _result;
  String? _advisoryTier;

  @override
  void initState() {
    super.initState();
    _audioService = widget.breathAudioService ?? BreathAudioService();
    _acousticEngine = widget.coughAcousticEngine ?? CoughAcousticEngine();
    _storageService = widget.storageService ?? StorageService();
    _behaviorEngine = BehaviorEngine();
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
    setState(() {
      _phase = _CoughTestPhase.listening;
      _secondsRemaining = _testDurationSeconds;
    });

    await _audioService.startListening((sample) {
      _samples.add(sample);
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

  Future<void> _finishTest() async {
    await _audioService.stopListening();
    final analysis = _acousticEngine.analyze(
      _samples,
      testDurationSeconds: _testDurationSeconds,
    );
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
    );
    await _storageService.saveCoughTestRecord(record);

    final healthConditions = await _storageService.loadHealthConditions();
    final priorRecords = await _storageService.loadCoughTestRecords(limit: 30);
    final fourteenDaysAgo = DateTime.now().subtract(const Duration(days: 14));
    const moderateOrWorse = {'moderate', 'severe', 'urgent'};
    final recentModerateOrWorseCount = priorRecords
        .where((r) => r.createdAt.isAfter(fourteenDaysAgo))
        .where((r) => moderateOrWorse.contains(r.severityLevel))
        .length;
    final advisoryTier = _behaviorEngine.resolveCoughAdvisoryTier(
      latestSeverityLevel: record.severityLevel,
      healthConditions: healthConditions,
      recentModerateOrWorseCountLast14Days: recentModerateOrWorseCount,
    );

    unawaited(
      NotificationService.showCoughTestResultAdvisory(
        coughCount: record.coughCount,
        severityLevel: advisoryTier,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _result = record;
      _advisoryTier = advisoryTier;
      _phase = _CoughTestPhase.finished;
    });
    widget.onCompleted?.call();
  }

  String _severityTextKey(String tier) {
    switch (tier) {
      case 'mild':
        return 'coughTestSeverityMild';
      case 'moderate':
        return 'coughTestSeverityModerate';
      case 'severe':
        return 'coughTestSeveritySevere';
      case 'urgent':
        return 'coughTestSeverityUrgent';
      default:
        return 'coughTestSeverityNormal';
    }
  }

  String? _tipTextKey(String tier) {
    switch (tier) {
      case 'mild':
        return 'coughTipMild';
      case 'moderate':
        return 'coughTipModerate';
      case 'severe':
        return 'coughTipSevere';
      case 'urgent':
        return 'coughTipUrgent';
      default:
        return null;
    }
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildBody(context),
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
    final tier = _advisoryTier;
    if (result == null || tier == null) {
      return const SizedBox.shrink();
    }
    final tipKey = _tipTextKey(tier);
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Text(
            context.t('coughTestResultTitle'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            context
                .t('coughTestResultCount')
                .replaceAll('{count}', '${result.coughCount}'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.t(_severityTextKey(tier)),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
          if (tipKey != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(context.t(tipKey)),
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
      ),
    );
  }
}
