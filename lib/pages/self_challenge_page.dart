import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../core/app_theme.dart';
import 'craving_sos_page.dart';

/// A user-initiated "don't smoke for N minutes" countdown — started from the
/// floating action button / app shortcut menu, not by the adaptive task
/// system. Deliberately lightweight: no TaskAssignmentService row, no
/// watchdog, no adaptive-learning signal (see the floating-menu decision
/// this was built for) — just a countdown the user can walk away from or
/// give up on, same as setting a kitchen timer. Ending early is not
/// recorded as a failure anywhere; there is nothing to fail.
class SelfChallengePage extends StatefulWidget {
  final int durationMinutes;

  const SelfChallengePage({super.key, required this.durationMinutes});

  @override
  State<SelfChallengePage> createState() => _SelfChallengePageState();
}

class _SelfChallengePageState extends State<SelfChallengePage> {
  late Duration _remaining = Duration(minutes: widget.durationMinutes);
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (_remaining <= const Duration(seconds: 1)) {
      _ticker?.cancel();
      if (!mounted) return;
      setState(() => _remaining = Duration.zero);
      return;
    }
    setState(() => _remaining -= const Duration(seconds: 1));
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final finished = _remaining == Duration.zero;
    return Scaffold(
      backgroundColor: AppTheme.noSmokeNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(context.t('selfChallengeTitle')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Text(
                finished
                    ? context.t('selfChallengeDone')
                    : context.t('selfChallengeInProgress'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                _format(_remaining),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(flex: 3),
              if (finished)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEEEEE),
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      context.t('selfChallengeCloseButton'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CravingSosPage(),
                      ),
                    ),
                    child: Text(context.t('cravingSosButton')),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      context.t('selfChallengeGiveUpButton'),
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
