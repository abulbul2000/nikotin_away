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

// `resumed` is the barrier-was-running case: SOS suspended a task already
// in its no-smoking window, so there's nothing to ask about timing —
// dismissing just hands it straight back to counting down.
enum _SosStage { breathing, suggestion, resume, resumed }

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
  final StorageService _storage = StorageService();

  /// The task this SOS actually applies to — known synchronously the moment
  /// the page opens whenever [widget.taskCanonicalTitle] was passed in (the
  /// notification-SOS path), so the resume-choice UI doesn't have to wait on
  /// a database round trip to appear. [_wasBarrierRunning] answers a
  /// different question (was it already mid-barrier?) and can only be known
  /// after that lookup, so it starts false and is resolved separately in
  /// [_resolveActiveTask].
  String? _resolvedTaskTitle;
  bool _wasBarrierRunning = false;

  @override
  void initState() {
    super.initState();
    _suggestionKey = _suggestionKeys[Random().nextInt(_suggestionKeys.length)];
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _secondsLeft),
    )..forward();
    _startTimer();
    _resolvedTaskTitle = widget.taskCanonicalTitle;
    unawaited(_resolveActiveTask());
  }

  /// Whether the resolved task was already mid-barrier (`accepted`) when SOS
  /// opened, so it can be suspended into `sosActive` and resumed later
  /// rather than treated as a fresh postpone. [widget.taskCanonicalTitle]
  /// covers the notification-SOS path; when it's null (home-screen menu,
  /// self-challenge, a coach nudge) this looks up whichever barrier is
  /// currently running, if any, so suspending it doesn't depend on which
  /// door the user walked in through.
  Future<void> _resolveActiveTask() async {
    final explicitTitle = widget.taskCanonicalTitle;
    if (explicitTitle != null && explicitTitle.isNotEmpty) {
      final task = await _storage.loadLatestTaskAssignmentByTitle(
        explicitTitle,
      );
      final wasRunning = task?.state == TaskLifecycleState.accepted;
      if (wasRunning) {
        await _storage.transitionTaskAssignment(
          id: task!.id,
          state: TaskLifecycleState.sosActive,
        );
      }
      if (!mounted) return;
      setState(() {
        _wasBarrierRunning = wasRunning;
      });
      return;
    }

    // No task was handed in — check whether a barrier is running anyway
    // (home-screen SOS menu, self-challenge, a coach nudge mid-barrier).
    final active = await _storage.loadActiveAcceptedBarrier();
    if (active == null) {
      return;
    }
    await _storage.transitionTaskAssignment(
      id: active.id,
      state: TaskLifecycleState.sosActive,
    );
    if (!mounted) return;
    setState(() {
      _resolvedTaskTitle = active.canonicalTitle;
      _wasBarrierRunning = true;
    });
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
  ///
  /// Only reached when the barrier wasn't already running (see
  /// [_resumeBarrier] for that case) — this is the notification-SOS path,
  /// where the task hadn't started counting down yet, so "how long until
  /// you're asked again" is still a real question.
  Future<void> _resumeTaskIn(int minutes) async {
    final title = _resolvedTaskTitle;
    if (title != null && title.isNotEmpty) {
      final task = await _storage.loadLatestTaskAssignmentByTitle(title);
      if (task != null) {
        await _storage.transitionTaskAssignment(
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

  /// The barrier-was-running case: resumes the same task back into
  /// `accepted` (see storage_service.dart's `transitionTaskAssignment`,
  /// which leaves `barrierStartedAt`/`barrierEndsAt` untouched on this
  /// specific transition) so it keeps counting down on whatever time was
  /// actually left, rather than being treated as a fresh postpone.
  Future<void> _resumeBarrier() async {
    final title = _resolvedTaskTitle;
    if (title != null && title.isNotEmpty) {
      final task = await _storage.loadLatestTaskAssignmentByTitle(title);
      if (task != null) {
        await _storage.transitionTaskAssignment(
          id: task.id,
          state: TaskLifecycleState.accepted,
          sosMinutes: DateTime.now().difference(_openedAt).inMinutes,
        );
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t('sosBarrierResumed'))));
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
            _SosStage.resumed => _buildResumed(),
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
    if (_resolvedTaskTitle == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(
      () => _stage = _wasBarrierRunning
          ? _SosStage.resumed
          : _SosStage.resume,
    );
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
            onPressed: _handleDismiss,
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

  /// The barrier-was-running case — no timing question, since the barrier
  /// itself is already resuming. This is the moment [_wasBarrierRunning]
  /// exists to recognise: getting through a craving without smoking, on a
  /// task already in its window, is the strongest evidence the programme
  /// ever gets, so it's said outright rather than folded into a generic
  /// "resumed" toast.
  Widget _buildResumed() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.emoji_events_outlined, size: 56, color: AppTheme.brandPrimary),
        const SizedBox(height: 20),
        Text(
          context.t('sosBarrierResumedTitle'),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 12),
        Text(
          context.t('sosBarrierResumedBody'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const ValueKey('sos_barrier_resumed_button'),
            onPressed: _resumeBarrier,
            child: Text(context.t('sosBarrierResumedAction')),
          ),
        ),
      ],
    );
  }
}
