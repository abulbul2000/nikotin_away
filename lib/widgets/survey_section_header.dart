import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Visually separates a long form into clearly labeled sections, with an
/// icon, a title, and a divider line. Used to break up scrolling forms
/// (like the detailed weekly survey) into readable groups without
/// changing any of the surrounding field logic.
class SurveySectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool withTopSpacing;

  const SurveySectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.withTopSpacing = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: withTopSpacing ? 24 : 0, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                 color: AppTheme.noSmokeGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: AppTheme.noSmokeGreen),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
