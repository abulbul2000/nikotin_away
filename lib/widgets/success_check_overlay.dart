import 'package:flutter/material.dart';

/// Large centered checkmark shown briefly to confirm the microphone
/// captured a valid attempt (an exhale, a cough). Purely decorative —
/// callers await [show] and then continue their existing flow.
class SuccessCheckOverlay {
  static Future<void> show(BuildContext context) async {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(builder: (_) => const _SuccessCheckAnimation());
    overlay.insert(entry);
    await Future.delayed(const Duration(milliseconds: 900));
    entry.remove();
  }
}

class _SuccessCheckAnimation extends StatefulWidget {
  const _SuccessCheckAnimation();

  @override
  State<_SuccessCheckAnimation> createState() => _SuccessCheckAnimationState();
}

class _SuccessCheckAnimationState extends State<_SuccessCheckAnimation>
    with SingleTickerProviderStateMixin {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() => _visible = true);
      Future.delayed(const Duration(milliseconds: 650), () {
        if (!mounted) {
          return;
        }
        setState(() => _visible = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedScale(
              scale: _visible ? 1 : 0.6,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 72,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
