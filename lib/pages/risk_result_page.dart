import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../models/survey_record.dart';
import '../models/user_behavior_profile.dart';
import '../models/user_profile_snapshot.dart';
import '../services/storage_service.dart';
import 'home_page.dart';

class RiskResultPage extends StatelessWidget {
  final String name;
  final int riskScore;
  final String riskLevel;
  final String packsPerDay;
  final int exhaleTestSeconds;
  final int inhaleTestSeconds;
  final UserBehaviorProfile? behaviorProfile;

  const RiskResultPage({
    super.key,
    required this.name,
    required this.riskScore,
    required this.riskLevel,
    this.packsPerDay = '1 paketten az',
    this.exhaleTestSeconds = 0,
    this.inhaleTestSeconds = 0,
    this.behaviorProfile,
  });

  Color getRiskColor() {
    if (riskScore >= 80) {
      return Colors.red;
    }
    if (riskScore >= 60) {
      return Colors.orange;
    }
    if (riskScore >= 40) {
      return Colors.yellow;
    }
    return Colors.green;
  }

  String _localizedRiskLabel(BuildContext context) {
    if (riskScore >= 80) {
      return context.t('riskCritical');
    }
    if (riskScore >= 60) {
      return context.t('riskHigh');
    }
    if (riskScore >= 40) {
      return context.t('riskMedium');
    }
    return context.t('riskLow');
  }

  int getTaskCount() {
    if (riskScore >= 80) return 5;
    if (riskScore >= 60) return 4;
    if (riskScore >= 40) return 3;
    if (riskScore >= 20) return 2;
    return 1;
  }

  String getRiskDescription() {
    if (riskScore >= 80) {
      return 'riskDescCritical';
    }

    if (riskScore >= 60) {
      return 'riskDescHigh';
    }

    if (riskScore >= 40) {
      return 'riskDescMedium';
    }

    return 'riskDescLow';
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'notSpecified';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _getSubscriptionType() {
    final type = behaviorProfile?.subscriptionType.toLowerCase();
    if (type == 'premium') {
      return 'premium';
    }
    return 'free';
  }

  String _getUsageDuration() {
    final startDate = behaviorProfile?.subscriptionStartDate;
    if (startDate == null) {
      return 'notSpecified';
    }
    final endDate = behaviorProfile?.subscriptionEndDate ?? DateTime.now();
    final days = endDate.difference(startDate).inDays;
    return '$days {days}';
  }

  String _getTrialStatus() {
    return behaviorProfile?.trialActive == true ? 'active' : 'passive';
  }

  String _getPremiumStatus() {
    return behaviorProfile?.premiumFeaturesEnabled == true ? 'yes' : 'no';
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usageDuration = _getUsageDuration().replaceAll(
      '{days}',
      context.t('days'),
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.t('riskAnalysis'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              '${context.t('hello')} $name',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 25),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: getRiskColor(),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    _localizedRiskLabel(context),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$riskScore / 100',
                    style: const TextStyle(fontSize: 24, color: Colors.black),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            Text(
              context.t(getRiskDescription()),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 25),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      context.t('taskCountToday'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${getTaskCount()} ${context.t('taskUnit')}',
                      style: const TextStyle(fontSize: 26),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('subscriptionInfo'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      context.t('subscriptionType'),
                      context.t(_getSubscriptionType()),
                    ),
                    _buildInfoRow(
                      context.t('subscriptionStart'),
                      _formatDate(behaviorProfile?.subscriptionStartDate),
                    ),
                    _buildInfoRow(
                      context.t('subscriptionEnd'),
                      _formatDate(behaviorProfile?.subscriptionEndDate),
                    ),
                    _buildInfoRow(context.t('totalUsage'), usageDuration),
                    _buildInfoRow(
                      context.t('trialStatus'),
                      context.t(_getTrialStatus()),
                    ),
                    _buildInfoRow(
                      context.t('premiumActive'),
                      context.t(_getPremiumStatus()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  context.t('weeklySavePrompt'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                key: const ValueKey('risk_result_continue_button'),
                onPressed: () async {
                  try {
                    final storage = StorageService();
                    final breathTitle = context.t('breathTestRecordTitle');
                    final adjustedRiskCritical = context.t('riskCritical');
                    final adjustedRiskHigh = context.t('riskHigh');
                    final adjustedRiskMedium = context.t('riskMedium');
                    final adjustedRiskLow = context.t('riskLow');
                    final adjustedRiskScore = await storage
                        .calculateAdjustedRiskScore(
                          baseScore: riskScore,
                          exhaleSeconds: exhaleTestSeconds,
                          inhaleSeconds: inhaleTestSeconds,
                        );
                    if (!context.mounted) return;
                    final adjustedRiskLevel = adjustedRiskScore >= 80
                        ? adjustedRiskCritical
                        : adjustedRiskScore >= 60
                        ? adjustedRiskHigh
                        : adjustedRiskScore >= 40
                        ? adjustedRiskMedium
                        : adjustedRiskLow;
                    final currentRecord = SurveyRecord(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      completedAt: DateTime.now(),
                      type: 'breath_test',
                      title: breathTitle,
                      name: name,
                      packsPerDay: packsPerDay,
                      exhaleTestSeconds: exhaleTestSeconds,
                      inhaleTestSeconds: inhaleTestSeconds,
                      riskScore: adjustedRiskScore,
                      riskLevel: adjustedRiskLevel,
                    );

                    await storage.saveSurveyRecord(currentRecord);
                    await storage.saveUserProfileSnapshot(
                      UserProfileSnapshot(
                        id: 'profile_${currentRecord.id}',
                        createdAt: currentRecord.completedAt,
                        riskScore: adjustedRiskScore,
                        packsPerDay: packsPerDay,
                        firstCigaretteRange: 'unknown',
                        smokeFreeRange: 'unknown',
                        consecutiveSmokingHabit:
                            currentRecord.consecutiveSmokingHabit ?? 'Hayır',
                        consecutiveSmokingCount:
                            currentRecord.consecutiveSmokingCount,
                        triggers: const [],
                        healthConditions: const [],
                        profession: 'Belirtilmedi',
                        sleepTime: '21:00',
                        wakeTime: '07:00',
                        latestExhaleSeconds: exhaleTestSeconds,
                        latestInhaleSeconds: inhaleTestSeconds,
                      ),
                    );

                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HomePage(
                          name: name,
                          riskScore: adjustedRiskScore,
                          riskLevel: adjustedRiskLevel,
                          autoCompleteRegistrationOnLoad: true,
                        ),
                      ),
                      (route) => false,
                    );
                  } catch (error, stackTrace) {
                    debugPrint(
                      '[RiskResultPage] Failed to save result/continue: $error',
                    );
                    debugPrintStack(stackTrace: stackTrace);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Kayıt sırasında bir hata oluştu. Lütfen tekrar deneyin.',
                          ),
                        ),
                      );
                  }
                },
                child: Text(
                  context.t('continue'),
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
