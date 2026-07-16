import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../models/survey_record.dart';
import '../services/storage_service.dart';
import '../widgets/no_smoke_logo.dart';
import 'breath_test_page.dart';
import 'survey_page.dart';

class TrialInfoPage extends StatelessWidget {
  const TrialInfoPage({super.key});

  Map<String, dynamic> _resolveHomeSeed(List<SurveyRecord> records) {
    String name = 'User';
    String packsPerDay = '1 paketten az';

    for (final record in records.reversed) {
      if (record.name.toString().trim().isNotEmpty) {
        name = record.name.toString().trim();
        break;
      }
    }

    for (final record in records.reversed) {
      if (record.type == 'breath_test' ||
          record.type == 'weekly' ||
          record.type == 'initial') {
        packsPerDay = record.packsPerDay;
        break;
      }
    }

    return {'name': name, 'packsPerDay': packsPerDay};
  }

  Future<void> _continue(BuildContext context) async {
    final storage = StorageService();
    final records = await storage.loadSurveyHistory();
    final hasInitialSetup = records.any((record) => record.type == 'initial');

    if (!context.mounted) {
      return;
    }

    if (!hasInitialSetup) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SurveyPage()),
      );
      return;
    }

    final seed = _resolveHomeSeed(records);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BreathTestPage(
          name: seed['name'] as String,
          packsPerDay: seed['packsPerDay'] as String,
          navigateToHomeOnComplete: true,
          askWeeklySurveyOnComplete: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const NoSmokeLogo(size: 150, showLabel: true),
                  const SizedBox(height: 24),
                  Text(
                    context.t('trialInfoTitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        context.t('trialInfoMessage'),
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.45,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => _continue(context),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: Text(context.t('continue')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
