import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../services/storage_service.dart';
import 'survey_page.dart';

/// A short, skippable first-use guide shown before the initial survey.
/// Each topic is a separate step so the user can move back and forth.
class HowItWorksPage extends StatefulWidget {
  const HowItWorksPage({super.key});

  static const seenSettingKey = 'how_it_works_guide_seen';

  @override
  State<HowItWorksPage> createState() => _HowItWorksPageState();
}

class _HowItWorksPageState extends State<HowItWorksPage> {
  int _currentIndex = 0;

  List<_GuideStep> _steps(BuildContext context) => [
        _GuideStep(
          icon: Icons.person_search_outlined,
          title: context.t('initialSurvey'),
          body: context.t('trialInfoMessage'),
        ),
        _GuideStep(
          icon: Icons.cloud_sync_outlined,
          title: context.t('loginTitle'),
          body: context.t('loginSubtitle'),
        ),
        _GuideStep(
          icon: Icons.touch_app_outlined,
          title: context.t('smokedLogButtonTitle'),
          body: context.t('smokedLogButtonPurpose'),
        ),
        _GuideStep(
          icon: Icons.auto_awesome_outlined,
          title: context.t('mentorCardTitle'),
          body: context.t('aiChatDisclaimer'),
        ),
        _GuideStep(
          icon: Icons.insights_outlined,
          title: context.t('taskReasonCardTitle'),
          body: context.t('reductionNoDataBody'),
        ),
        _GuideStep(
          icon: Icons.health_and_safety_outlined,
          title: context.t('breathTestPageTitle'),
          body: context.t('breathExerciseDisclaimer'),
        ),
        _GuideStep(
          icon: Icons.bedtime_outlined,
          title: context.t('sleepIntelligenceTitle'),
          body: context.t('sleepIntelligencePurpose'),
        ),
        _GuideStep(
          icon: Icons.admin_panel_settings_outlined,
          title: context.t('permissionSetupTitle'),
          body: context.t('permissionSetupOptionalHint'),
        ),
      ];

  Future<void> _finish(BuildContext context) async {
    await StorageService().saveSetting(
      HowItWorksPage.seenSettingKey,
      '1',
    );
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SurveyPage()),
    );
  }

  void _goNext(BuildContext context, int length) {
    if (_currentIndex == length - 1) {
      _finish(context);
      return;
    }
    setState(() => _currentIndex += 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final steps = _steps(context);
    final step = steps[_currentIndex];
    final isLast = _currentIndex == steps.length - 1;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(context.t('appName')),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_currentIndex + 1) / steps.length,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_currentIndex + 1}/${steps.length}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: SingleChildScrollView(
                  key: ValueKey(_currentIndex),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 112,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          step.icon,
                          size: 58,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        step.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 18),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            step.body,
                            textAlign: TextAlign.start,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(height: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _currentIndex == 0
                          ? null
                          : () => setState(() => _currentIndex -= 1),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 54),
                      ),
                      child: Text(context.t('back')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => _goNext(context, steps.length),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 54),
                      ),
                      child: Text(
                        isLast ? context.t('start') : context.t('continue'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStep {
  final IconData icon;
  final String title;
  final String body;

  const _GuideStep({
    required this.icon,
    required this.title,
    required this.body,
  });
}
