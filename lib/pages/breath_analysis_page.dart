import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../core/app_theme.dart';
import '../engines/breath_trend_engine.dart';
import '../models/breath_badge.dart';
import '../models/breath_progress_summary.dart';
import '../services/breath_badge_service.dart';
import '../services/storage_service.dart';
import '../widgets/load_error_view.dart';
import 'breath_test_page.dart';

class _AnalysisData {
  final BreathProgressSummary summary;
  final List<BreathBadge> badges;

  const _AnalysisData({required this.summary, required this.badges});
}

class BreathAnalysisPage extends StatefulWidget {
  const BreathAnalysisPage({super.key});

  @override
  State<BreathAnalysisPage> createState() => _BreathAnalysisPageState();
}

class _BreathAnalysisPageState extends State<BreathAnalysisPage> {
  final StorageService _storageService = StorageService();
  final BreathTrendEngine _trendEngine = BreathTrendEngine();
  final BreathBadgeService _badgeService = BreathBadgeService();

  late Future<_AnalysisData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_AnalysisData> _loadData() async {
    final records = await _storageService.loadBreathProgressRecords();
    final summary = _trendEngine.summarize(records);
    // Badges are (re-)evaluated on every load, not only right after a test —
    // this is the one place users actually look at their breath-test
    // history, so it's the natural point to surface a newly-earned badge
    // even if it was technically unlocked by a test taken elsewhere (e.g.
    // navigateToHomeOnComplete flows that never route through here).
    await _badgeService.evaluateProgress(records);
    final badges = await _badgeService.loadAll();
    return _AnalysisData(summary: summary, badges: badges);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('breathAnalysisPageTitle'))),
      body: FutureBuilder<_AnalysisData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return LoadErrorView(
              onRetry: () => setState(() => _dataFuture = _loadData()),
            );
          }

          final data = snapshot.data!;
          if (!data.summary.hasData) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _dataFuture = _loadData();
              });
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCards(context, data.summary),
                const SizedBox(height: 12),
                _buildScoreChartCard(context, data.summary),
                const SizedBox(height: 12),
                _buildWeeklyBarChartCard(context, data.summary),
                const SizedBox(height: 12),
                _buildBadgesCard(context, data.badges),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.air, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              context.t('breathAnalysisEmptyTitle'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.t('breathAnalysisEmptyBody'),
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BreathTestPage()),
                );
              },
              child: Text(context.t('breathAnalysisEmptyCta')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, BreathProgressSummary summary) {
    final progressLabel = summary.scoreChangeFirstWeekVsLastWeekPercent == null
        ? '-'
        : '${summary.scoreChangeFirstWeekVsLastWeekPercent! >= 0 ? '+' : ''}'
            '${summary.scoreChangeFirstWeekVsLastWeekPercent!.toStringAsFixed(0)}%';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statTile(
                context.t('breathAnalysisSummaryProgressLabel'),
                progressLabel,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statTile(
                context.t('breathAnalysisSummaryBestScoreLabel'),
                summary.bestScore.toStringAsFixed(0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statTile(
                context.t('breathAnalysisSummaryConsistencyLabel'),
                '${(summary.last30Days.averageStability * 100).toStringAsFixed(0)}%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statTile(
                context.t('breathAnalysisSummaryTestCountLabel'),
                '${summary.totalTestCount}',
              ),
            ),
          ],
        ),
        if (summary.insightMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              summary.insightMessage,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  Widget _statTile(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreChartCard(BuildContext context, BreathProgressSummary summary) {
    // Last 30 days of chart points — the model already carries the whole
    // history, chart just windows it for readability.
    final points = summary.chartPoints.length <= 30
        ? summary.chartPoints
        : summary.chartPoints.sublist(summary.chartPoints.length - 30);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('breathAnalysisScoreChartTitle'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (!summary.hasEnoughDataForTrend) ...[
              const SizedBox(height: 8),
              Text(
                context.t('breathAnalysisNotEnoughDataTitle'),
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: points.isEmpty
                  ? Center(child: Text(context.t('breathAnalysisEmptyTitle')))
                  : _ScoreLineChart(points: points),
            ),
            if (points.any((p) => p.hasSkippedNoisyTest)) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.t('breathAnalysisNoisyLegend'),
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyBarChartCard(BuildContext context, BreathProgressSummary summary) {
    final weeklyAverages = _weeklyAverages(summary.chartPoints);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('breathAnalysisWeeklyAverageTitle'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: weeklyAverages.isEmpty
                  ? Center(child: Text(context.t('breathAnalysisEmptyTitle')))
                  : _WeeklyBarChart(weeklyAverages: weeklyAverages),
            ),
          ],
        ),
      ),
    );
  }

  /// Groups the daily chart points into calendar weeks (Monday-start) and
  /// averages each week's raw scores — the last up-to-8 weeks that have at
  /// least one real score.
  List<double> _weeklyAverages(List<BreathProgressChartPoint> points) {
    final byWeek = <DateTime, List<double>>{};
    for (final point in points) {
      final score = point.rawScore;
      if (score == null) {
        continue;
      }
      final weekStart = point.date.subtract(
        Duration(days: point.date.weekday - 1),
      );
      (byWeek[weekStart] ??= []).add(score);
    }

    final weeks = byWeek.keys.toList()..sort();
    final averages = weeks
        .map((week) {
          final scores = byWeek[week]!;
          return scores.reduce((a, b) => a + b) / scores.length;
        })
        .toList();

    return averages.length <= 8
        ? averages
        : averages.sublist(averages.length - 8);
  }

  Widget _buildBadgesCard(BuildContext context, List<BreathBadge> badges) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('breathAnalysisBadgesTitle'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: badges.length,
              itemBuilder: (context, index) => _BreathBadgeTile(badge: badges[index]),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreathBadgeTile extends StatelessWidget {
  final BreathBadge badge;

  const _BreathBadgeTile({required this.badge});

  @override
  Widget build(BuildContext context) {
    final locked = !badge.unlocked;
    return Tooltip(
      message:
          '${context.t(badge.titleKey)}\n${context.t(badge.descriptionKey)}',
      child: Container(
        decoration: BoxDecoration(
          color: locked ? const Color(0xFF0F1B2A) : const Color(0xFF132238),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: locked ? 0.3 : 1,
              child: Text(badge.icon, style: const TextStyle(fontSize: 28)),
            ),
            if (locked) ...[
              const SizedBox(height: 4),
              const Icon(Icons.lock_outline, size: 12, color: Colors.white24),
            ],
          ],
        ),
      ),
    );
  }
}

/// 30-day score chart: faint raw daily points behind a solid 7-day moving
/// average line — single testler gün gün çok dalgalı olabildiği için asıl
/// anlatılan eğilim kayan ortalama, ham noktalar sadece arka planda bağlam
/// sağlıyor.
class _ScoreLineChart extends StatelessWidget {
  final List<BreathProgressChartPoint> points;

  const _ScoreLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final rawSpots = <FlSpot>[];
    final averageSpots = <FlSpot>[];
    final noisyDayIndices = <int>{};

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      if (point.rawScore != null) {
        rawSpots.add(FlSpot(i.toDouble(), point.rawScore!));
      }
      if (point.movingAverageScore != null) {
        averageSpots.add(FlSpot(i.toDouble(), point.movingAverageScore!));
      }
      if (point.hasSkippedNoisyTest) {
        noisyDayIndices.add(i);
      }
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 25,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: Colors.white54),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (points.length / 4).clamp(1, double.infinity),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                final date = points[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${date.day}/${date.month}',
                    style: const TextStyle(fontSize: 10, color: Colors.white54),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          // Raw daily points — faint, no connecting line, noisy days shown
          // in a different color so users can see why a day looks odd.
          LineChartBarData(
            spots: rawSpots,
            isCurved: false,
            barWidth: 0,
            color: Colors.transparent,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                final pointIndex = spot.x.toInt();
                final isNoisy = noisyDayIndices.contains(pointIndex);
                return FlDotCirclePainter(
                  radius: 2.5,
                  color: (isNoisy ? Colors.orangeAccent : AppTheme.brandPrimary)
                      .withValues(alpha: 0.45),
                );
              },
            ),
          ),
          // The moving average — the actual trend line.
          LineChartBarData(
            spots: averageSpots,
            isCurved: true,
            barWidth: 3,
            color: AppTheme.brandPrimary,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  final List<double> weeklyAverages;

  const _WeeklyBarChart({required this.weeklyAverages});

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: 100,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 25,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: Colors.white54),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final weekIndex = value.toInt() + 1;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'W$weekIndex',
                    style: const TextStyle(fontSize: 10, color: Colors.white54),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < weeklyAverages.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: weeklyAverages[i],
                  color: AppTheme.brandPrimary,
                  width: 18,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
