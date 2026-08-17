import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../core/app_theme.dart';

/// Screen shown after the user taps a health-tip notification.
///
/// The acknowledgement label intentionally uses `doneShort`, while task
/// screens continue using their own task action label.
class HealthTipPage extends StatelessWidget {
  final String body;
  final Future<void> Function()? onAcknowledged;

  const HealthTipPage({
    super.key,
    required this.body,
    this.onAcknowledged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text(
                context.t('healthTipTitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              CircleAvatar(
                radius: 46,
                backgroundColor: AppTheme.brandPrimary.withValues(alpha: 0.25),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const ValueKey('health_tip_done_button'),
                  onPressed: () async {
                    await onAcknowledged?.call();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(context.t('doneShort')),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
