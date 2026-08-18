import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../models/user_behavior_profile.dart';
import 'home_page.dart';

class RiskResultPage extends StatelessWidget {
  final String name;
  final int riskScore;
  final String riskLevel;
  final String packsPerDay;
  final int exhaleTestSeconds;
  final int inhaleTestSeconds;
  final UserBehaviorProfile? behaviorProfile;

  /// True when this result followed a breath test attempt (even one without
  /// a full acoustic reading, which is why it landed here instead of
  /// BreathSpirometryResultPage) — shows the doctor-consultation disclaimer
  /// that only makes sense in a breathing-test context, not for the other
  /// survey flows that also land on this shared page.
  final bool showBreathDisclaimer;

  const RiskResultPage({
    super.key,
    required this.name,
    required this.riskScore,
    required this.riskLevel,
    this.packsPerDay = '1 paketten az',
    this.exhaleTestSeconds = 0,
    this.inhaleTestSeconds = 0,
    this.behaviorProfile,
    this.showBreathDisclaimer = false,
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

  String _formatDate(BuildContext context, DateTime? date) {
    if (date == null) {
      return context.t('notSpecified');
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

  String _getUsageDuration(BuildContext context) {
    final startDate = behaviorProfile?.subscriptionStartDate;
    if (startDate == null) {
      return context.t('notSpecified');
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
    final usageDuration = _getUsageDuration(
      context,
    ).replaceAll('{days}', context.t('days'));

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
                      _formatDate(
                        context,
                        behaviorProfile?.subscriptionStartDate,
                      ),
                    ),
                    _buildInfoRow(
                      context.t('subscriptionEnd'),
                      _formatDate(
                        context,
                        behaviorProfile?.subscriptionEndDate,
                      ),
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
            if (showBreathDisclaimer) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  context.t('breathSpirometryEstimateDisclaimer'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                key: const ValueKey('risk_result_continue_button'),
                onPressed: () {
                  // The risk score/level shown on this screen was already
                  // computed and persisted by whichever flow got the user
                  // here (BreathTestService.processBreathTest, via the
                  // single canonical BehaviorEngine-driven risk formula) —
                  // this screen only displays it, it does not recompute or
                  // re-save a second, independent adjustment.
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HomePage(
                        name: name,
                        riskScore: riskScore,
                        riskLevel: riskLevel,
                        autoCompleteRegistrationOnLoad: true,
                      ),
                    ),
                    (route) => false,
                  );
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
