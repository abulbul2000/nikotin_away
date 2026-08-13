import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../engines/breath_trend_engine.dart';
import '../models/breath_progress_summary.dart';
import '../services/language_service.dart';
import '../services/storage_service.dart';
import 'home_page.dart';

/// Shown after a breath test that got a full acoustic reading, instead of
/// the generic [RiskResultPage] — presents the attempt's own 0-100 breath
/// score plus a short trend note against the user's own history, alongside
/// the same risk box every result screen shows.
///
/// Deliberately does not show FEV1/FVC ratios, peak flow, or a flow-time
/// curve: this is a self-comparison score, not a clinical measurement — see
/// [BreathTrendEngine.computeScore] and the CLAUDE.md rule against clinical
/// framing of uncalibrated acoustic readings.
class BreathSpirometryResultPage extends StatefulWidget {
  final String name;
  final int riskScore;
  final String riskLevel;
  final double breathScore;

  /// Whether an acoustic wheeze was detected on this attempt — shown as a
  /// single neutral note, never a severity level (see
  /// [WheezeDetectionEngine]'s own doc comment: uncalibrated per-device).
  final bool wheezeDetected;

  const BreathSpirometryResultPage({
    super.key,
    required this.name,
    required this.riskScore,
    required this.riskLevel,
    required this.breathScore,
    this.wheezeDetected = false,
  });

  @override
  State<BreathSpirometryResultPage> createState() =>
      _BreathSpirometryResultPageState();
}

class _BreathSpirometryResultPageState
    extends State<BreathSpirometryResultPage> {
  final StorageService _storageService = StorageService();
  final BreathTrendEngine _trendEngine = BreathTrendEngine();
  late Future<BreathProgressSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
  }

  Future<BreathProgressSummary> _loadSummary() async {
    final records = await _storageService.loadBreathProgressRecords();
    final languageCode = await LanguageService.loadSelectedLanguageCode();
    return _trendEngine.summarize(records, languageCode: languageCode);
  }

  Color _riskColor() {
    if (widget.riskScore >= 80) {
      return Colors.red;
    }
    if (widget.riskScore >= 60) {
      return Colors.orange;
    }
    if (widget.riskScore >= 40) {
      return Colors.yellow;
    }
    return Colors.green;
  }

  String _localizedRiskLabel(BuildContext context) {
    if (widget.riskScore >= 80) {
      return context.t('riskCritical');
    }
    if (widget.riskScore >= 60) {
      return context.t('riskHigh');
    }
    if (widget.riskScore >= 40) {
      return context.t('riskMedium');
    }
    return context.t('riskLow');
  }

  @override
  Widget build(BuildContext context) {
    final color = _riskColor();
    return Scaffold(
      appBar: AppBar(title: Text(context.t('breathSpirometryResultTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color, width: 2),
            ),
            child: Column(
              children: [
                Text(
                  '${widget.riskScore} / 100',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _localizedRiskLabel(context),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.t('breathScoreLabel'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${widget.breathScore.toStringAsFixed(0)} / 100',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<BreathProgressSummary>(
                    future: _summaryFuture,
                    builder: (context, snapshot) {
                      final insight = snapshot.data?.insightMessage;
                      if (insight == null || insight.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        insight,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (widget.wheezeDetected) ...[
            const SizedBox(height: 20),
            Card(
              key: const ValueKey('breath_result_wheeze_card'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('wheezeFindingSectionTitle'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t('breathUnusualSoundDetected'),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.t('breathUnusualSoundAdvice'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              context.t('breathScoreDisclaimer'),
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('breath_result_continue'),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => HomePage(
                    name: widget.name,
                    riskScore: widget.riskScore,
                    riskLevel: widget.riskLevel,
                  ),
                ),
                (route) => false,
              );
            },
            child: Text(context.t('doneShort')),
          ),
        ],
      ),
    );
  }
}
