import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../services/storage_service.dart';
import 'survey_page.dart';

/// A short, skippable first-use guide. It deliberately reuses existing
/// translated strings so every supported locale gets a complete explanation.
class HowItWorksPage extends StatelessWidget {
  const HowItWorksPage({super.key});

  static const seenSettingKey = 'how_it_works_guide_seen';

  Future<void> _continue(BuildContext context) async {
    await StorageService().saveSetting(seenSettingKey, '1');
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SurveyPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(context.t('appName')),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.t('trialInfoTitle'),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.t('trialInfoMessage'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 20),
                    _GuideCard(
                      icon: Icons.person_search_outlined,
                      title: context.t('initialSurvey'),
                      body: context.t('trialInfoMessage'),
                    ),
                    _GuideCard(
                      icon: Icons.cloud_sync_outlined,
                      title: context.t('loginTitle'),
                      body: context.t('loginSubtitle'),
                    ),
                    _GuideCard(
                      icon: Icons.touch_app_outlined,
                      title: context.t('smokedLogButtonTitle'),
                      body: context.t('smokedLogButtonPurpose'),
                    ),
                    _GuideCard(
                      icon: Icons.auto_awesome_outlined,
                      title: context.t('mentorCardTitle'),
                      body: context.t('aiChatDisclaimer'),
                    ),
                    _GuideCard(
                      icon: Icons.insights_outlined,
                      title: context.t('taskReasonCardTitle'),
                      body: context.t('reductionNoDataBody'),
                    ),
                    _GuideCard(
                      icon: Icons.health_and_safety_outlined,
                      title: context.t('breathTestPageTitle'),
                      body: context.t('breathExerciseDisclaimer'),
                    ),
                    _GuideCard(
                      icon: Icons.bedtime_outlined,
                      title: context.t('sleepIntelligenceTitle'),
                      body: context.t('sleepIntelligencePurpose'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t('permissionSetupOptionalHint'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                onPressed: () => _continue(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                ),
                child: Text(context.t('continue')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _GuideCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(body, style: const TextStyle(height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
