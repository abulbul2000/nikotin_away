import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../core/app_theme.dart';
import '../models/health_milestone.dart';
import '../services/health_recovery_service.dart';

class HealthRecoveryPage extends StatelessWidget {
  final DateTime quitDate;

  const HealthRecoveryPage({super.key, required this.quitDate});

  @override
  Widget build(BuildContext context) {
    final progress = HealthRecoveryService().computeProgress(quitDate);
    final reachedIds = progress.reached.map((m) => m.titleKey).toSet();

    return Scaffold(
      appBar: AppBar(title: Text(context.t('healthRecoveryPageTitle'))),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: HealthMilestone.timeline.length,
        itemBuilder: (context, index) {
          final milestone = HealthMilestone.timeline[index];
          final reached = reachedIds.contains(milestone.titleKey);
          final isNext = progress.next?.titleKey == milestone.titleKey;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: reached ? const Color(0xFF132238) : const Color(0xFF0F1B2A),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(milestone.icon, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t(milestone.titleKey),
                            style: TextStyle(
                              color: reached ? Colors.white : Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.t(milestone.descriptionKey),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          if (isNext) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress.nextProgress,
                                minHeight: 6,
                                backgroundColor: Colors.white12,
                                valueColor: const AlwaysStoppedAnimation(
                                  AppTheme.brandPrimary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (reached)
                      const Icon(Icons.check_circle,
                          color: AppTheme.brandPrimary, size: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

}
