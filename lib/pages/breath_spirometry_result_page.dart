import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../engines/breath_acoustic_engine.dart';
import '../engines/wheeze_detection_engine.dart';
import 'home_page.dart';

/// Shown after a breath test that got a full acoustic reading, instead of
/// the generic [RiskResultPage] — presents the forceful-exhale attempt's
/// spirometry-style estimates (FEV1/FVC ratio, peak flow index, flow-time
/// curve) alongside the same risk box every result screen shows.
///
/// Every number here is explicitly labeled as an uncalibrated estimate
/// (see [SpirometryEstimate]'s doc comment) — a phone microphone has no
/// validated energy-to-airflow conversion, so nothing on this screen is
/// shown in liters or claims to match a real spirometer.
class BreathSpirometryResultPage extends StatelessWidget {
  final String name;
  final int riskScore;
  final String riskLevel;
  final SpirometryEstimate spirometry;

  /// Acoustic wheeze finding from the same attempt — null when detection
  /// never accumulated enough windows even though exhale timing succeeded,
  /// or [WheezeAnalysis.wheezeDetected] is false.
  final WheezeAnalysis? wheeze;
  final String? wheezeAdvisoryTier;

  const BreathSpirometryResultPage({
    super.key,
    required this.name,
    required this.riskScore,
    required this.riskLevel,
    required this.spirometry,
    this.wheeze,
    this.wheezeAdvisoryTier,
  });

  Color _riskColor() {
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

  /// Neutral, non-diagnostic banding — never "abnormal"/"COPD risk", matches
  /// docs/copd_like_breath_test_design.md's language rules.
  String _ratioInterpretation(BuildContext context) {
    if (spirometry.fev1FvcRatioPercent >= 70) {
      return context.t('breathRatioBandNormalRange');
    }
    return context.t('breathRatioBandMonitor');
  }

  String _peakFlowInterpretation(BuildContext context) {
    if (spirometry.peakFlowIndex >= 50) {
      return context.t('breathPeakFlowBandNormalRange');
    }
    return context.t('breathPeakFlowBandMonitor');
  }

  String _wheezeSeverityTextKey(String severityLevel) {
    switch (severityLevel) {
      case 'severe':
        return 'wheezeSeveritySevere';
      case 'moderate':
        return 'wheezeSeverityModerate';
      default:
        return 'wheezeSeverityMild';
    }
  }

  String _wheezeAdviceTextKey(String advisoryTier) {
    switch (advisoryTier) {
      case 'severe':
        return 'wheezeAdviceSevere';
      case 'moderate':
        return 'wheezeAdviceModerate';
      default:
        return 'wheezeAdviceMild';
    }
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
                  '$riskScore / 100',
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
                  Text(
                    context.t('breathSpirometrySummaryTitle'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _MetricRow(
                    key: const ValueKey('breath_result_ratio'),
                    label: context.t('breathFev1FvcRatioLabel'),
                    value:
                        '${spirometry.fev1FvcRatioPercent.toStringAsFixed(0)}%',
                    suffix: context.t('breathEstimatedValueSuffix'),
                    interpretation: _ratioInterpretation(context),
                  ),
                  const SizedBox(height: 12),
                  _MetricRow(
                    key: const ValueKey('breath_result_peak_flow'),
                    label: context.t('breathPeakFlowIndexLabel'),
                    value:
                        '${spirometry.peakFlowIndex.toStringAsFixed(0)}/100',
                    suffix: context.t('breathEstimatedValueSuffix'),
                    interpretation: _peakFlowInterpretation(context),
                  ),
                ],
              ),
            ),
          ),
          if (wheeze != null && wheeze!.wheezeDetected) ...[
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
                      context.t(_wheezeSeverityTextKey(wheeze!.severityLevel)),
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (wheezeAdvisoryTier != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        context.t(_wheezeAdviceTextKey(wheezeAdvisoryTier!)),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('breathFlowCurveSectionTitle'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _FlowTimeCurvePainter(
                        curve: spirometry.curve,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('breathSpirometryNotEquivalentWarning'),
                  style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 8),
                Text(
                  context.t('breathSpirometryEstimateDisclaimer'),
                  style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('breath_result_continue'),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => HomePage(
                    name: name,
                    riskScore: riskScore,
                    riskLevel: riskLevel,
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

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final String interpretation;

  const _MetricRow({
    super.key,
    required this.label,
    required this.value,
    required this.suffix,
    required this.interpretation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Text(
              suffix,
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          interpretation,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

/// Plots the downsampled energy-time curve, shading the first-second (FEV1)
/// region distinctly from the rest of the exhale (FVC) — the one genuinely
/// new chart on this screen, everything else is stat tiles/text. Follows
/// personal_progress_page.dart's _MiniLinePainter axis/path approach: no
/// charting package, fully offline.
class _FlowTimeCurvePainter extends CustomPainter {
  final List<BreathFlowCurvePoint> curve;

  _FlowTimeCurvePainter({required this.curve});

  static const int _fev1WindowMs = 1000;

  @override
  void paint(Canvas canvas, Size size) {
    if (curve.isEmpty) {
      return;
    }

    final axisPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = Colors.lightBlueAccent
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    final fev1FillPaint = Paint()
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.25);

    const chartLeft = 8.0;
    final chartRight = size.width - 8;
    const chartTop = 8.0;
    final chartBottom = size.height - 10;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;

    canvas.drawLine(
      Offset(chartLeft, chartBottom),
      Offset(chartRight, chartBottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(chartLeft, chartTop),
      Offset(chartLeft, chartBottom),
      axisPaint,
    );

    final maxMs = curve.last.millisecondsSinceOnset.toDouble();
    final timeSpan = maxMs <= 0 ? 1.0 : maxMs;
    final maxEnergy = curve
        .map((p) => p.energy)
        .reduce((a, b) => a > b ? a : b);
    final energySpan = maxEnergy <= 0 ? 1.0 : maxEnergy;

    Offset pointFor(BreathFlowCurvePoint p) {
      final t = p.millisecondsSinceOnset / timeSpan;
      final x = chartLeft + (t.clamp(0, 1) * chartWidth);
      final normalized = p.energy / energySpan;
      final y = chartBottom - (normalized.clamp(0, 1) * chartHeight);
      return Offset(x, y);
    }

    // Shade the FEV1 sub-region (0-1000ms) under the curve before drawing
    // the line on top, so the line stays crisp.
    if (maxMs > 0) {
      final fev1Fraction = (_fev1WindowMs / timeSpan).clamp(0.0, 1.0);
      final fev1Right = chartLeft + (fev1Fraction * chartWidth);
      canvas.drawRect(
        Rect.fromLTRB(chartLeft, chartTop, fev1Right, chartBottom),
        fev1FillPaint,
      );
    }

    final path = Path();
    for (var i = 0; i < curve.length; i++) {
      final offset = pointFor(curve[i]);
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _FlowTimeCurvePainter oldDelegate) =>
      oldDelegate.curve != curve;
}
