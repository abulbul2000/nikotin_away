import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../core/app_theme.dart';
import '../models/task_assignment.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

/// Full-screen page for riding out a craving: a guided 4-7-8 breathing cycle,
/// then a concrete thing to do instead.
///
/// When it was opened from a task ([taskCanonicalTitle] set), that task is
/// suspended rather than failed, and the user chooses when to be handed back
/// to it. SOS is meant to be an escape from the craving, not from the
/// programme — cancelling the task outright would make it the cheapest way to
/// never answer one.
class CravingSosPage extends StatefulWidget {
  /// The `ADAPTIVE_NO_SMOKE:<minutes>` form of the task that was interrupted,
  /// or null when the user opened this from the home screen unprompted.
  final String? taskCanonicalTitle;

  const CravingSosPage({super.key, this.taskCanonicalTitle});

  @override
  State<CravingSosPage> createState() => _CravingSosPageState();
}

enum _BreathPhase { inhale, hold, exhale }

enum _SosStage { breathing, suggestion, resume }

class _CravingSosPageState extends State<CravingSosPage>
    with SingleTickerProviderStateMixin {
  static const _phaseDurations = {
    _BreathPhase.inhale: 4,
    _BreathPhase.hold: 7,
    _BreathPhase.exhale: 8,
  };

  static const _suggestionKeys = [
    'sosSuggestionWater',
    'sosSuggestionWalk',
    'sosSuggestionCall',
    'sosSuggestionStretch',
    'sosSuggestionWash',
  ];

  _BreathPhase _phase = _BreathPhase.inhale;
  _SosStage _stage = _SosStage.breathing;
  int _secondsLeft = _phaseDurations[_BreathPhase.inhale]!;
  int _cyclesCompleted = 0;
  Timer? _timer;
  late final AnimationController _pulseController;
  late final String _suggestionKey;
  final DateTime _openedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _suggestionKey = _suggestionKeys[Random().nextInt(_suggestionKeys.length)];
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _secondsLeft),
    )..forward();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _secondsLeft -= 1;
        if (_secondsLeft <= 0) {
          _advancePhase();
        }
      });
    });
  }

  void _advancePhase() {
    switch (_phase) {
      case _BreathPhase.inhale:
        _phase = _BreathPhase.hold;
        break;
      case _BreathPhase.hold:
        _phase = _BreathPhase.exhale;
        break;
      case _BreathPhase.exhale:
        _phase = _BreathPhase.inhale;
        _cyclesCompleted += 1;
        break;
    }
    _secondsLeft = _phaseDurations[_phase]!;
    _pulseController
      ..duration = Duration(seconds: _secondsLeft)
      ..forward(from: 0);
  }

  String get _phaseLabel {
    switch (_phase) {
      case _BreathPhase.inhale:
        return context.t('sosPhaseInhale');
      case _BreathPhase.hold:
        return context.t('sosPhaseHold');
      case _BreathPhase.exhale:
        return context.t('sosPhaseExhale');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  /// Hands the interrupted task back after [minutes], and records how long
  /// the SOS took so the watchdog's silence window isn't spent on breathing.
  Future<void> _resumeTaskIn(int minutes) async {
    final title = widget.taskCanonicalTitle;
    if (title != null && title.isNotEmpty) {
      final storage = StorageService();
      final task = await storage.loadLatestTaskAssignmentByTitle(title);
      if (task != null) {
        await storage.transitionTaskAssignment(
          id: task.id,
          state: TaskLifecycleState.postponed,
          postponeMinutes: minutes,
          sosMinutes: DateTime.now().difference(_openedAt).inMinutes,
        );
      }
      await NotificationService.scheduleFirstTaskTriggerNotification(
        taskDescription: title,
        delay: Duration(minutes: minutes),
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t('sosTaskPostponed'))));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.noSmokeNavy,
      appBar: AppBar(
        title: Text(context.t('sosPageTitle')),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: switch (_stage) {
            _SosStage.breathing => _buildBreathing(),
            _SosStage.suggestion => _buildSuggestion(),
            _SosStage.resume => _buildResume(),
          },
        ),
      ),
    );
  }

  Widget _buildBreathing() {
    final targetScale = _phase == _BreathPhase.exhale ? 0.9 : 1.3;
    final baseScale = _phase == _BreathPhase.inhale ? 0.9 : 1.3;

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          context.t('sosIntro'),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        Text(
          context
              .t('sosCyclesCompleted')
              .replaceAll('{count}', '$_cyclesCompleted'),
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const Spacer(),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale =
                baseScale + (targetScale - baseScale) * _pulseController.value;
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.brandPrimary.withValues(alpha: 0.18),
              border: Border.all(color: AppTheme.brandPrimary, width: 3),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _phaseLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$_secondsLeft',
                  style: const TextStyle(color: Colors.white70, fontSize: 28),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        Text(
          context.t('sosReassurance'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('sos_dismiss_button'),
                onPressed: _handleDismiss,
                child: Text(context.t('sosDismiss')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                key: const ValueKey('sos_suggestion_button'),
                onPressed: () => setState(() => _stage = _SosStage.suggestion),
                child: Text(context.t('sosNeedSuggestion')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// "I'm through it" still has to settle the task — leaving it mid-flight
  /// would mean the retry chain kept prompting someone who just told us they
  /// were past the craving.
  void _handleDismiss() {
    final title = widget.taskCanonicalTitle;
    if (title == null || title.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _stage = _SosStage.resume);
  }

  Widget _buildSuggestion() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.spa_outlined, size: 56, color: AppTheme.brandPrimary),
        const SizedBox(height: 20),
        Text(
          context.t('sosSuggestionTitle'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        Text(
          context.t(_suggestionKey),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const ValueKey('sos_suggestion_done_button'),
            onPressed: () {
              if (widget.taskCanonicalTitle == null) {
                Navigator.of(context).pop();
                return;
              }
              setState(() => _stage = _SosStage.resume);
            },
            child: Text(context.t('sosDismiss')),
          ),
        ),
      ],
    );
  }

  Widget _buildResume() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          context.t('sosResumeQuestion'),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 28),
        for (final (minutes, key) in const [
          (30, 'sosResume30'),
          (60, 'sosResume60'),
          (120, 'sosResume120'),
        ]) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: ValueKey('sos_resume_$minutes'),
              onPressed: () => _resumeTaskIn(minutes),
              child: Text(context.t(key)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
