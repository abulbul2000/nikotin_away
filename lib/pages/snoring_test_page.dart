import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../engines/snoring_acoustic_engine.dart';
import '../models/breath_acoustic_sample.dart';
import '../models/snoring_probe_event.dart';
import '../services/breath_audio_service.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../widgets/success_check_overlay.dart';

enum _SnoringTestPhase { notStarted, listening, finished }

/// A short (60s), user-initiated test the user can run any time during the
/// day — separate from the passive overnight probes SleepProbeReceiver.kt
/// runs while asleep, for someone who wants to check e.g. what they sound
/// like right now rather than waiting for tonight's summary.
class SnoringTestPage extends StatefulWidget {
  final bool navigateToHomeOnComplete;
  final VoidCallback? onCompleted;
  final BreathAudioService? breathAudioService;
  final SnoringAcousticEngine? snoringAcousticEngine;
  final StorageService? storageService;

  const SnoringTestPage({
    super.key,
    this.navigateToHomeOnComplete = false,
    this.onCompleted,
    this.breathAudioService,
    this.snoringAcousticEngine,
    this.storageService,
  });

  @override
  State<SnoringTestPage> createState() => _SnoringTestPageState();
}

class _SnoringTestPageState extends State<SnoringTestPage> {
  static const int _testDurationSeconds = 60;

  late final BreathAudioService _audioService;
  late final SnoringAcousticEngine _acousticEngine;
  late final StorageService _storageService;

  _SnoringTestPhase _phase = _SnoringTestPhase.notStarted;
  int _secondsRemaining = _testDurationSeconds;
  Timer? _countdownTimer;
  final List<BreathAcousticSample> _samples = [];
  bool _micPermissionRequested = false;

  SnoringAnalysis? _result;

  @override
  void initState() {
    super.initState();
    _audioService = widget.breathAudioService ?? BreathAudioService();
    _acousticEngine = widget.snoringAcousticEngine ?? SnoringAcousticEngine();
    _storageService = widget.storageService ?? StorageService();
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
      _phase = _SnoringTestPhase.listening;
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
    final analysis = _acousticEngine.analyze(_samples);

    if (analysis.snoreLikely) {
      if (mounted) {
        await SuccessCheckOverlay.show(context);
      }
    }
    if (!mounted) {
      return;
    }

    final record = SnoringProbeEvent(
      id: 'manualsnoreprobe_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      snoreLikely: analysis.snoreLikely,
      severityScore: analysis.severityScore,
      severityLevel: analysis.severityLevel,
    );
    await _storageService.saveManualSnoringProbe(record);

    if (!mounted) {
      return;
    }
    setState(() {
      _result = analysis;
      _phase = _SnoringTestPhase.finished;
    });
    widget.onCompleted?.call();
  }

  String _severityTextKey(String level) {
    switch (level) {
      case 'mild':
        return 'snoringSeverityMild';
      case 'moderate':
        return 'snoringSeverityModerate';
      case 'severe':
        return 'snoringSeveritySevere';
      default:
        return 'snoringSeverityNone';
    }
  }

  String? _adviceTextKey(String level) {
    switch (level) {
      case 'mild':
        return 'snoringAdviceMild';
      case 'moderate':
        return 'snoringAdviceModerate';
      case 'severe':
        return 'snoringAdviceSevere';
      default:
        return null;
    }
  }

  void _finish() {
    if (widget.navigateToHomeOnComplete) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.of(context).pop(_result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('snoringTestTitle'))),
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
      case _SnoringTestPhase.notStarted:
        return _buildNotStarted(context);
      case _SnoringTestPhase.listening:
        return _buildListening(context);
      case _SnoringTestPhase.finished:
        return _buildFinished(context);
    }
  }

  Widget _buildNotStarted(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.bedtime_outlined, size: 72),
        const SizedBox(height: 20),
        Text(
          context.t('snoringTestInstructions'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _startTest,
            child: Text(context.t('snoringTestStartButton')),
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
          context.t('snoringTestListening'),
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
    final adviceKey = _adviceTextKey(result.severityLevel);
    return SingleChildScrollView(
      child: Column(
        key: const ValueKey('snoring_result_card'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Text(
            context.t('snoringTestResultTitle'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            context.t(_severityTextKey(result.severityLevel)),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (adviceKey != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(context.t(adviceKey)),
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
