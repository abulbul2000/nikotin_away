import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../models/behavior_dashboard.dart';
import '../models/survey_record.dart';
import '../services/storage_service.dart';
import '../widgets/load_error_view.dart';

class PersonalProgressPage extends StatefulWidget {
  const PersonalProgressPage({super.key});

  @override
  State<PersonalProgressPage> createState() => _PersonalProgressPageState();
}

class _PersonalProgressPageState extends State<PersonalProgressPage> {
  final StorageService _storageService = StorageService();

  late Future<_ProgressData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_ProgressData> _loadData() async {
    final history = await _storageService.loadSurveyHistory();
    final breathMetrics = await _storageService.loadBreathMetrics();
    final breathProgress = await _storageService.loadBreathProgressReport();
    final taskSummary = await _storageService.loadTaskOutcomeSummary();
    final behavior = await _storageService.loadLatestBehaviorSnapshot();
    final surveyContextById = await _storageService
        .loadSurveyContextByRecordId();

    return _ProgressData(
      history: history,
      breathMetrics: breathMetrics,
      breathProgress: breathProgress,
      taskSummary: taskSummary,
      behavior: behavior,
      surveyContextById: surveyContextById,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('menuPersonalProgress'))),
      body: FutureBuilder<_ProgressData>(
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
          final surveys = data.history
              .where((r) => r.type == 'initial' || r.type == 'weekly')
              .toList();
          final breathTests = data.history
              .where((r) => r.type == 'breath_test')
              .toList();
          final weeklyRecords = data.history
              .where((r) => r.type == 'weekly')
              .toList();

          final firstRecord = surveys.isNotEmpty ? surveys.first : null;
          final latestRecord = surveys.isNotEmpty ? surveys.last : null;
          final riskDelta = firstRecord == null || latestRecord == null
              ? 0
              : latestRecord.riskScore - firstRecord.riskScore;

          final firstBreath = breathTests.isNotEmpty
              ? ((breathTests.first.exhaleTestSeconds +
                            breathTests.first.inhaleTestSeconds) /
                        2)
                    .toDouble()
              : 0.0;
          final latestBreath = breathTests.isNotEmpty
              ? ((breathTests.last.exhaleTestSeconds +
                            breathTests.last.inhaleTestSeconds) /
                        2)
                    .toDouble()
              : 0.0;
          final breathDelta = latestBreath - firstBreath;

          final weeklyImprovements = _countWeeklyImprovements(weeklyRecords);
          final bestBreathStreak = _bestDailyBreathStreak(breathTests);
          final weeklyRiskTrend = _weeklyRiskTrend(weeklyRecords);
          final breathTrend = _breathDailyTrend(breathTests);
          final respiratoryTrend = _weeklyRespiratoryTrend(
            weeklyRecords,
            data.surveyContextById,
          );
          final latestRespiratory = _latestRespiratorySnapshot(
            weeklyRecords,
            data.surveyContextById,
          );
          final respiratoryAlerts = _respiratoryAlertTimeline(
            weeklyRecords,
            data.surveyContextById,
          );

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _dataFuture = _loadData();
              });
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionCard(
                  title: context.t('progressSummaryTitle'),
                  children: [
                    _row(context.t('totalRecords'), '${data.history.length}'),
                    _row(
                      context.t('menuWeeklySurvey'),
                      '${weeklyRecords.length}',
                    ),
                    _row(context.t('menuBreathTest'), '${breathTests.length}'),
                    _row(
                      context.t('latestRiskScore'),
                      data.behavior?.riskScore.toString() ?? '-',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  title: context.t('breathProgressTitle'),
                  children: [
                    _row(
                      context.t('dailyAverageLabel'),
                      (data.breathMetrics['dailyAverage'] ?? 0).toStringAsFixed(
                        1,
                      ),
                    ),
                    _row(
                      context.t('weeklyAverageLabel'),
                      (data.breathMetrics['weeklyAverage'] ?? 0)
                          .toStringAsFixed(1),
                    ),
                    _row(
                      context.t('monthlyAverageLabel'),
                      (data.breathMetrics['monthlyAverage'] ?? 0)
                          .toStringAsFixed(1),
                    ),
                    _row(
                      context.t('firstToLastAverageDiff'),
                      breathTests.isEmpty
                          ? '-'
                          : '${breathDelta >= 0 ? '+' : ''}${breathDelta.toStringAsFixed(1)} sn',
                    ),
                    _row(
                      context.t('latestVsPrevious'),
                      ((data.breathProgress['deltaFromPrevious'] as num?)
                                  ?.toDouble() ??
                              0)
                          .toStringAsFixed(1),
                    ),
                    _row(
                      context.t('bestConsecutiveDay'),
                      '$bestBreathStreak ${context.t('dayUnit')}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  title: context.t('respFollowUpTitle'),
                  children: [
                    _row(
                      context.t('latestRespBurden'),
                      latestRespiratory == null
                          ? '-'
                          : '${(_toDouble(latestRespiratory['burden'])).toStringAsFixed(1)} / 100',
                    ),
                    _row(
                      context.t('latestStatus'),
                      latestRespiratory == null
                          ? '-'
                          : _respiratoryStateLabel(
                              latestRespiratory['state']?.toString() ??
                                  'stable',
                            ),
                    ),
                    _row(
                      context.t('mmrcLikeGrade'),
                      latestRespiratory == null
                          ? '-'
                          : '${_toInt(latestRespiratory['mmrc'])}',
                    ),
                    _row(
                      context.t('catLikeTotal'),
                      latestRespiratory == null
                          ? '-'
                          : '${_toInt(latestRespiratory['catTotal'])} / 40',
                    ),
                    _row(
                      context.t('warningDaysTotal'),
                      latestRespiratory == null
                          ? '-'
                          : '${_toInt(latestRespiratory['warningTotal'])} / 28',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.t('respFollowUpNote'),
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  title: context.t('trendChartsTitle'),
                  children: [
                    Text(
                      context.t('weeklyRiskTrendTitle'),
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (weeklyRiskTrend.isEmpty)
                      Text(context.t('noWeeklyDataForChart'))
                    else
                      _MiniLineChart(
                        values: weeklyRiskTrend,
                        height: 130,
                        color: Colors.redAccent,
                        lineLabel: 'Risk',
                      ),
                    const SizedBox(height: 12),
                    Text(
                      context.t('breathTrendTitle'),
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (breathTrend.isEmpty)
                      Text(context.t('noBreathDataForChart'))
                    else
                      _MiniLineChart(
                        values: breathTrend,
                        height: 130,
                        color: Colors.blueAccent,
                        lineLabel: 'sn',
                      ),
                    const SizedBox(height: 12),
                    Text(
                      context.t('respiratoryTrendTitle'),
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (respiratoryTrend.isEmpty)
                      Text(context.t('noRespDataForChart'))
                    else
                      _MiniLineChart(
                        values: respiratoryTrend,
                        height: 130,
                        color: Colors.deepOrange,
                        lineLabel: 'yuk',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  title: context.t('taskBarrierComplianceTitle'),
                  children: [
                    _row(
                      context.t('successfulTaskCount'),
                      '${data.taskSummary['successCount'] ?? 0}',
                    ),
                    _row(
                      context.t('failedTaskCount'),
                      '${data.taskSummary['failureCount'] ?? 0}',
                    ),
                    _row(
                      context.t('last10Successful'),
                      '${data.taskSummary['recentSuccessCount'] ?? 0}',
                    ),
                    _row(
                      context.t('last10Failed'),
                      '${data.taskSummary['recentFailureCount'] ?? 0}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  title: context.t('achievementsSinceStartTitle'),
                  children: [
                    _row(
                      context.t('riskChange'),
                      firstRecord == null || latestRecord == null
                          ? '-'
                          : '${firstRecord.riskScore} -> ${latestRecord.riskScore} (${riskDelta >= 0 ? '+' : ''}$riskDelta)',
                    ),
                    _row(
                      context.t('weeklyImprovementPeriod'),
                      '$weeklyImprovements ${context.t('weeklySurvey')}',
                    ),
                    _row(
                      context.t('planDayLabel'),
                      data.behavior == null
                          ? '-'
                          : '${data.behavior!.plan.currentDay}/${data.behavior!.plan.targetDays}',
                    ),
                    _row(
                      context.t('remainingDaysLabel'),
                      data.behavior?.plan.daysRemaining.toString() ?? '-',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  title: context.t('respAlertHistoryTitle'),
                  children: respiratoryAlerts.isEmpty
                      ? [Text(context.t('noCriticalRespAlertRecord'))]
                      : respiratoryAlerts
                            .take(12)
                            .map(
                              (line) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(line),
                              ),
                            )
                            .toList(),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  title: context.t('weeklyHistoryTitle'),
                  children: weeklyRecords.isEmpty
                      ? [Text(context.t('noWeeklyRecordYet'))]
                      : weeklyRecords.reversed
                            .take(20)
                            .map(
                              (r) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '${_dateLabel(r.completedAt)}  |  ${context.t('risk')}: ${r.riskScore} (${AppTexts.localizeCanonicalText(context, r.riskLevel)})  |  Paket: ${AppTexts.localizeCanonicalText(context, r.packsPerDay)}',
                                ),
                              ),
                            )
                            .toList(),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  title: context.t('breathTestHistoryTitle'),
                  children: breathTests.isEmpty
                      ? [Text(context.t('noBreathRecordYet'))]
                      : breathTests.reversed
                            .take(30)
                            .map(
                              (r) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '${_dateLabel(r.completedAt)}  |  ${r.exhaleTestSeconds}s / ${r.inhaleTestSeconds}s  |  Risk ${r.riskScore}',
                                ),
                              ),
                            )
                            .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _dateLabel(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$dd/$mm ${date.year} $hh:$min';
  }

  int _countWeeklyImprovements(List<SurveyRecord> weeklyRecords) {
    if (weeklyRecords.length < 2) {
      return 0;
    }
    var improved = 0;
    for (var i = 1; i < weeklyRecords.length; i++) {
      if (weeklyRecords[i].riskScore < weeklyRecords[i - 1].riskScore) {
        improved += 1;
      }
    }
    return improved;
  }

  int _bestDailyBreathStreak(List<SurveyRecord> breathRecords) {
    if (breathRecords.isEmpty) {
      return 0;
    }

    final dates =
        breathRecords
            .map(
              (r) => DateTime(
                r.completedAt.year,
                r.completedAt.month,
                r.completedAt.day,
              ),
            )
            .toSet()
            .toList()
          ..sort((a, b) => a.compareTo(b));

    var best = 1;
    var current = 1;
    for (var i = 1; i < dates.length; i++) {
      final diff = dates[i].difference(dates[i - 1]).inDays;
      if (diff == 1) {
        current += 1;
        if (current > best) {
          best = current;
        }
      } else {
        current = 1;
      }
    }
    return best;
  }

  List<double> _weeklyRiskTrend(List<SurveyRecord> weeklyRecords) {
    if (weeklyRecords.isEmpty) {
      return const [];
    }
    final values = weeklyRecords
        .map((record) => record.riskScore.toDouble())
        .toList();
    return values.length <= 12 ? values : values.sublist(values.length - 12);
  }

  List<double> _breathDailyTrend(List<SurveyRecord> breathRecords) {
    if (breathRecords.isEmpty) {
      return const [];
    }

    final grouped = <DateTime, List<double>>{};
    for (final record in breathRecords) {
      final day = DateTime(
        record.completedAt.year,
        record.completedAt.month,
        record.completedAt.day,
      );
      final avg = ((record.exhaleTestSeconds + record.inhaleTestSeconds) / 2)
          .toDouble();
      grouped.putIfAbsent(day, () => <double>[]).add(avg);
    }

    final days = grouped.keys.toList()..sort((a, b) => a.compareTo(b));
    final trend = <double>[];
    for (final day in days) {
      final values = grouped[day] ?? const <double>[];
      if (values.isEmpty) {
        continue;
      }
      final sum = values.reduce((a, b) => a + b);
      trend.add(sum / values.length);
    }

    return trend.length <= 14 ? trend : trend.sublist(trend.length - 14);
  }

  List<double> _weeklyRespiratoryTrend(
    List<SurveyRecord> weeklyRecords,
    Map<String, Map<String, dynamic>> contextById,
  ) {
    if (weeklyRecords.isEmpty) {
      return const [];
    }

    final values = <double>[];
    for (final record in weeklyRecords) {
      final payload = _weeklyPayloadForRecord(record.id, contextById);
      if (payload == null) {
        continue;
      }
      final snapshot = _respiratorySnapshot(payload);
      values.add((snapshot['burden'] as num).toDouble());
    }

    return values.length <= 12 ? values : values.sublist(values.length - 12);
  }

  Map<String, dynamic>? _latestRespiratorySnapshot(
    List<SurveyRecord> weeklyRecords,
    Map<String, Map<String, dynamic>> contextById,
  ) {
    for (final record in weeklyRecords.reversed) {
      final payload = _weeklyPayloadForRecord(record.id, contextById);
      if (payload == null) {
        continue;
      }
      return _respiratorySnapshot(payload);
    }
    return null;
  }

  List<String> _respiratoryAlertTimeline(
    List<SurveyRecord> weeklyRecords,
    Map<String, Map<String, dynamic>> contextById,
  ) {
    final alerts = <String>[];
    for (final record in weeklyRecords.reversed) {
      final payload = _weeklyPayloadForRecord(record.id, contextById);
      if (payload == null) {
        continue;
      }
      final snapshot = _respiratorySnapshot(payload);
      final state = snapshot['state']?.toString() ?? 'stable';
      if (state == 'stable') {
        continue;
      }
      final date = _dateLabel(record.completedAt);
      final burden = (snapshot['burden'] as num).toDouble().toStringAsFixed(1);
      alerts.add('$date  |  ${_respiratoryStateLabel(state)}  |  Yuk: $burden');
    }
    return alerts;
  }

  Map<String, dynamic>? _weeklyPayloadForRecord(
    String recordId,
    Map<String, Map<String, dynamic>> contextById,
  ) {
    final context = contextById[recordId];
    if (context == null) {
      return null;
    }
    final payload = context['weeklyPayload'] as Map<String, dynamic>?;
    if (payload == null || payload.isEmpty) {
      return null;
    }
    return payload;
  }

  Map<String, dynamic> _respiratorySnapshot(Map<String, dynamic> payload) {
    final respiratory =
        payload['respiratory'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final catLike =
        respiratory['catLike'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final warningSigns =
        respiratory['warningSigns'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    final mmrc = _toInt(respiratory['mmrcGrade']).clamp(1, 5);
    final catTotal =
        _toInt(catLike['cough']) +
        _toInt(catLike['phlegm']) +
        _toInt(catLike['chestTightness']) +
        _toInt(catLike['breathlessnessStairs']) +
        _toInt(catLike['activityLimitation']) +
        _toInt(catLike['confidenceLeavingHome']) +
        _toInt(catLike['sleepQualityResp']) +
        _toInt(catLike['energyLevelResp']);

    final warningNight = _toInt(
      warningSigns['increasedNightBreathlessnessDays'],
    ).clamp(0, 7);
    final warningSputumInc = _toInt(
      warningSigns['sputumIncreaseDays'],
    ).clamp(0, 7);
    final warningSputumColor = _toInt(
      warningSigns['sputumColorChangeDays'],
    ).clamp(0, 7);
    final warningWheeze = _toInt(warningSigns['wheezeDays']).clamp(0, 7);
    final warningTotal =
        warningNight + warningSputumInc + warningSputumColor + warningWheeze;

    final mmrcComponent = ((mmrc - 1) / 4) * 100;
    final catComponent = (catTotal / 40) * 100;
    final warningComponent = ((warningTotal / 28) * 100).clamp(0, 100);
    final burden =
        ((0.35 * mmrcComponent) +
                (0.45 * catComponent) +
                (0.20 * warningComponent))
            .clamp(0, 100)
            .toDouble();

    final severeCombo =
        (mmrc >= 4 && warningNight >= 4) ||
        (warningNight >= 4 && warningSputumColor >= 3);
    final state = burden >= 65 || severeCombo
        ? 'clinical_review_recommended'
        : burden >= 35 || warningNight >= 3 || warningSputumColor >= 2
        ? 'monitor_closer'
        : 'stable';

    return {
      'burden': burden,
      'state': state,
      'mmrc': mmrc,
      'catTotal': catTotal,
      'warningTotal': warningTotal,
    };
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  String _respiratoryStateLabel(String state) {
    switch (state) {
      case 'monitor_closer':
        return context.t('respMonitorCloser');
      case 'clinical_review_recommended':
        return context.t('respClinicalReview');
      default:
        return context.t('respStable');
    }
  }
}

class _ProgressData {
  final List<SurveyRecord> history;
  final Map<String, double> breathMetrics;
  final Map<String, dynamic> breathProgress;
  final Map<String, int> taskSummary;
  final BehaviorDashboard? behavior;
  final Map<String, Map<String, dynamic>> surveyContextById;

  const _ProgressData({
    required this.history,
    required this.breathMetrics,
    required this.breathProgress,
    required this.taskSummary,
    required this.behavior,
    required this.surveyContextById,
  });
}

class _MiniLineChart extends StatelessWidget {
  final List<double> values;
  final double height;
  final Color color;
  final String lineLabel;

  const _MiniLineChart({
    required this.values,
    required this.height,
    required this.color,
    required this.lineLabel,
  });

  @override
  Widget build(BuildContext context) {
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _MiniLinePainter(values: values, color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Min: ${min.toStringAsFixed(1)} $lineLabel  |  Max: ${max.toStringAsFixed(1)} $lineLabel  |  Son: ${values.last.toStringAsFixed(1)} $lineLabel',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class _MiniLinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _MiniLinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    final chartLeft = 8.0;
    final chartRight = size.width - 8;
    final chartTop = 8.0;
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

    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final span = (maxValue - minValue).abs() < 0.001
        ? 1.0
        : (maxValue - minValue);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final t = values.length == 1 ? 0.0 : i / (values.length - 1);
      final x = chartLeft + (t * chartWidth);
      final normalized = (values[i] - minValue) / span;
      final y = chartBottom - (normalized * chartHeight);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      canvas.drawCircle(Offset(x, y), 2.2, Paint()..color = color);
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniLinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
