import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class StatisticCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;

  const StatisticCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppTheme.noSmokeGreen;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
