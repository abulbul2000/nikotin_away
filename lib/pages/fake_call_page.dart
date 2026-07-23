import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../core/app_theme.dart';

/// Result of a [FakeCallPage] interaction.
enum FakeCallOutcome { answered, postponed, cancelled }

/// A full-screen page styled to look like a real incoming-call screen. Used
/// to start a smoke-free commitment window ("duration barrier") in a way
/// that's much harder to ignore than a plain notification, and gives the
/// user social cover in a group setting — they can "take a call" instead of
/// explaining why they're stepping away from a cigarette.
///
/// Deliberately mirrors a real call screen's two-button layout (answer /
/// decline) rather than exposing three options — a third, smaller "İptal"
/// (cancel, 2h snooze) action sits below as a quiet text link so the main
/// illusion stays intact.
class FakeCallPage extends StatefulWidget {
  final String callerName;

  const FakeCallPage({super.key, required this.callerName});

  @override
  State<FakeCallPage> createState() => _FakeCallPageState();
}

class _FakeCallPageState extends State<FakeCallPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _finish(FakeCallOutcome outcome) {
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // A real incoming call can't be dismissed with the back button either
      // — keeping that true here is part of the illusion.
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Text(
                  context.t('fakeCallIncoming'),
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 1.0 + (_pulseController.value * 0.08);
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: CircleAvatar(
                    radius: 64,
                    backgroundColor: AppTheme.noSmokeGreen.withValues(
                      alpha: 0.25,
                    ),
                    child: Text(
                      widget.callerName.isEmpty
                          ? '?'
                          : widget.callerName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 48,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallButton(
                      key: const ValueKey('fake_call_decline_button'),
                      color: Colors.redAccent,
                      icon: Icons.call_end,
                      label: context.t('fakeCallDecline'),
                      onPressed: () => _finish(FakeCallOutcome.postponed),
                    ),
                    _CallButton(
                      key: const ValueKey('fake_call_answer_button'),
                      color: AppTheme.noSmokeGreen,
                      icon: Icons.call,
                      label: context.t('fakeCallAnswer'),
                      onPressed: () => _finish(FakeCallOutcome.answered),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton(
                  key: const ValueKey('fake_call_cancel_button'),
                  onPressed: () => _finish(FakeCallOutcome.cancelled),
                  child: Text(
                    context.t('fakeCallNotNow'),
                    style: const TextStyle(color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _CallButton({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}
