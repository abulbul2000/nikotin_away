import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class ProgressWidget extends StatelessWidget {
  final int currentDays;
  final int targetDays;
  final String label;

  const ProgressWidget({
    super.key,
    required this.currentDays,
    required this.targetDays,
    this.label = 'Sigarasız gün',
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        targetDays == 0 ? 0.0 : (currentDays / targetDays).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.noSmokeGreen),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$currentDays',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$targetDays günlük hedefe doğru',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }
}
