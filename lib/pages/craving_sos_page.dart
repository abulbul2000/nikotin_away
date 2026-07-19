import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Full-screen emergency page shown when the user taps the SOS / craving
/// button. Walks them through a short guided breathing cycle (4-7-8 style)
/// to ride out the urge, then offers quick distraction actions.
class CravingSosPage extends StatefulWidget {
  const CravingSosPage({super.key});

  @override
  State<CravingSosPage> createState() => _CravingSosPageState();
}

enum _BreathPhase { inhale, hold, exhale }

class _CravingSosPageState extends State<CravingSosPage>
    with SingleTickerProviderStateMixin {
  static const _phaseDurations = {
    _BreathPhase.inhale: 4,
    _BreathPhase.hold: 7,
    _BreathPhase.exhale: 8,
  };

  _BreathPhase _phase = _BreathPhase.inhale;
  int _secondsLeft = _phaseDurations[_BreathPhase.inhale]!;
  int _cyclesCompleted = 0;
  Timer? _timer;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
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
        return 'Nefes al';
      case _BreathPhase.hold:
        return 'Tut';
      case _BreathPhase.exhale:
        return 'Ver';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetScale = _phase == _BreathPhase.exhale ? 0.9 : 1.3;
    final baseScale = _phase == _BreathPhase.inhale ? 0.9 : 1.3;

    return Scaffold(
      backgroundColor: AppTheme.noSmokeNavy,
      appBar: AppBar(
        title: const Text('Şu an isteğim var'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text(
                'Bu his birkaç dakika içinde geçecek. Birlikte nefes alalım.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Text(
                '$_cyclesCompleted tur tamamlandı',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = baseScale +
                      (targetScale - baseScale) * _pulseController.value;
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                   color: AppTheme.noSmokeGreen.withValues(alpha: 0.18),
                    border: Border.all(color: AppTheme.noSmokeGreen, width: 3),
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
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'İstek dalgası genelde 3-5 dakikada zirve yapıp azalır. '
                'Sigara içmeden de bu anı atlatabilirsin.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Atlattım'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Hook point: navigate to a distraction task,
                        // e.g. Navigator.pushNamed(context, '/tasks').
                        Navigator.of(context).pop();
                      },
                      child: const Text('Görev ver'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
