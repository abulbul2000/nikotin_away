import 'package:flutter/material.dart';

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
      appBar: AppBar(title: const Text('Sağlık İyileşme Süreci')),
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
                            _labelFor(milestone),
                            style: TextStyle(
                              color: reached ? Colors.white : Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _descriptionFor(milestone),
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
                                  AppTheme.noSmokeGreen,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (reached)
                      const Icon(Icons.check_circle,
                          color: AppTheme.noSmokeGreen, size: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // NOTE: Replace with context.t(milestone.titleKey) once entries are
  // added to app_texts.dart / generated_language_data.dart.
  String _labelFor(HealthMilestone m) => _fallbackTitles[m.titleKey] ?? m.titleKey;

  String _descriptionFor(HealthMilestone m) =>
      _fallbackDescriptions[m.descriptionKey] ?? m.descriptionKey;

  static const _fallbackTitles = {
    'recoveryMin20Title': '20 dakika',
    'recoveryHour12Title': '12 saat',
    'recoveryDay1Title': '24 saat',
    'recoveryDay2Title': '48 saat',
    'recoveryDay3Title': '72 saat',
    'recoveryWeek2Title': '2 hafta',
    'recoveryMonth1Title': '1 ay',
    'recoveryMonth9Title': '9 ay',
    'recoveryYear1Title': '1 yıl',
    'recoveryYear5Title': '5 yıl',
    'recoveryYear10Title': '10 yıl',
  };

  static const _fallbackDescriptions = {
    'recoveryMin20Desc': 'Nabız ve kan basıncı normale dönmeye başlar.',
    'recoveryHour12Desc': 'Kandaki karbonmonoksit seviyesi normale düşer.',
    'recoveryDay1Desc': 'Kalp krizi riski azalmaya başlar.',
    'recoveryDay2Desc': 'Tat ve koku alma duyusu belirgin şekilde iyileşir.',
    'recoveryDay3Desc': 'Nefes almak kolaylaşır, enerji seviyesi artar.',
    'recoveryWeek2Desc': 'Kan dolaşımı ve akciğer fonksiyonu iyileşir.',
    'recoveryMonth1Desc': 'Öksürük ve nefes darlığı belirgin azalır.',
    'recoveryMonth9Desc': 'Akciğerlerdeki silyalar yeniden işlev kazanır.',
    'recoveryYear1Desc': 'Koroner kalp hastalığı riski yarı yarıya azalır.',
    'recoveryYear5Desc': 'İnme riski, hiç içmemiş biri seviyesine yaklaşır.',
    'recoveryYear10Desc': 'Akciğer kanseri riski yaklaşık yarıya iner.',
  };
}
