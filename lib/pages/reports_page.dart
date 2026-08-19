import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../engines/report_engine.dart';
import '../models/period_report.dart';
import '../services/pdf_report_service.dart';
import '../services/storage_service.dart';
import '../widgets/load_error_view.dart';
import '../widgets/share_app_sheet.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final StorageService _storageService = StorageService();
  final ReportEngine _reportEngine = ReportEngine();
  final PdfReportService _pdfReportService = PdfReportService();

  String _periodType = 'weekly';
  bool _loading = true;
  bool _busy = false;
  bool _hasError = false;
  PeriodReport? _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime, DateTime) _resolvePeriod() {
    final now = DateTime.now();
    final days = _periodType == 'weekly' ? 7 : 30;
    return (now.subtract(Duration(days: days)), now);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      final (periodStart, periodEnd) = _resolvePeriod();
      final surveyRecords = await _storageService.loadSurveyHistory();
      final taskHistory = await _storageService.loadTaskHistory();
      final smokingEvents = await _storageService.loadSmokingEvents(
        since: periodStart,
      );
      final stepSamples = await _storageService.loadStepCounterSamples(
        since: periodStart.subtract(const Duration(days: 1)),
      );

      final report = _reportEngine.buildReport(
        periodStart: periodStart,
        periodEnd: periodEnd,
        periodType: _periodType,
        allSurveyRecords: surveyRecords,
        allTaskHistory: taskHistory,
        smokingEventsInPeriod: smokingEvents,
        stepSamples: stepSamples,
      );

      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  Map<String, String> _labels(BuildContext context) {
    return {
      'title': context.t('reportsPdfTitle'),
      'cigarettesLogged': context.t('reportsCigarettesLogged'),
      'avgPerDay': context.t('reportsAvgPerDay'),
      'riskScore': context.t('reportsRiskScore'),
      'riskTrend': context.t('reportsRiskTrend'),
      'breathTrend': context.t('reportsBreathTrend'),
      'smokingTrend': context.t('reportsSmokingTrend'),
      'taskSuccess': context.t('reportsTaskSuccess'),
      'taskCompletionRate': context.t('reportsTaskCompletionRate'),
      'weeklySurveys': context.t('reportsWeeklySurveys'),
      'breathTests': context.t('reportsBreathTests'),
      'daysSinceQuit': context.t('reportsDaysSinceQuit'),
      'totalSteps': context.t('reportsTotalSteps'),
      'avgStepsPerDay': context.t('reportsAvgStepsPerDay'),
      'avertedCigarettes': context.t('reportsAvertedCigarettes'),
      'smokingTimePattern': context.t('reportsSmokingTimePattern'),
      'noDataYet': context.t('reportsNoDataYet'),
      'partMorning': context.t('reportsPartMorning'),
      'partMidday': context.t('reportsPartMidday'),
      'partAfternoon': context.t('reportsPartAfternoon'),
      'partEvening': context.t('reportsPartEvening'),
      'partNight': context.t('reportsPartNight'),
      'disclaimer': context.t('reportsDisclaimer'),
      'trendImproving': context.t('trendImproving'),
      'trendDeclining': context.t('trendDeclining'),
      'trendStable': context.t('trendStable'),
    };
  }

  Future<void> _preview() async {
    final report = _report;
    if (report == null) return;
    setState(() => _busy = true);
    await _pdfReportService.previewReport(
      report: report,
      labels: _labels(context),
    );
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<bool> _askToShareApp() async {
    return showShareAppSheet(context);
  }

  Future<void> _share() async {
    final report = _report;
    if (report == null) return;
    if (await _askToShareApp()) return;
    if (!mounted) return;
    setState(() => _busy = true);
    await _pdfReportService.shareReport(
      report: report,
      labels: _labels(context),
    );
    if (!mounted) return;
    setState(() => _busy = false);
  }

  String _trendLabel(String trend) {
    switch (trend) {
      case 'Improving':
        return context.t('trendImproving');
      case 'Declining':
        return context.t('trendDeclining');
      default:
        return context.t('trendStable');
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      appBar: AppBar(title: Text(context.t('reportsTitle'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'weekly',
                  label: Text(context.t('reportsWeeklyTab')),
                ),
                ButtonSegment(
                  value: 'monthly',
                  label: Text(context.t('reportsMonthlyTab')),
                ),
              ],
              selected: {_periodType},
              onSelectionChanged: (selection) {
                setState(() {
                  _periodType = selection.first;
                });
                _load();
              },
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_hasError)
            Expanded(child: LoadErrorView(onRetry: _load))
          else if (report == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _ReportRow(
                    label: context.t('reportsCigarettesLogged'),
                    value: '${report.cigarettesLogged}',
                  ),
                  _ReportRow(
                    label: context.t('reportsAvgPerDay'),
                    value: report.avgCigarettesPerDay.toStringAsFixed(1),
                  ),
                  if (report.riskScoreAtStart != null &&
                      report.riskScoreAtEnd != null)
                    _ReportRow(
                      label: context.t('reportsRiskScore'),
                      value:
                          '${report.riskScoreAtStart} -> ${report.riskScoreAtEnd}',
                    ),
                  _ReportRow(
                    label: context.t('reportsRiskTrend'),
                    value: _trendLabel(report.riskTrend),
                  ),
                  _ReportRow(
                    label: context.t('reportsBreathTrend'),
                    value: _trendLabel(report.breathTrend),
                  ),
                  _ReportRow(
                    label: context.t('reportsSmokingTrend'),
                    value: _trendLabel(report.smokingTrend),
                  ),
                  _ReportRow(
                    label: context.t('reportsTaskSuccess'),
                    value:
                        '${report.taskSuccessCount}/${report.taskSuccessCount + report.taskFailureCount}',
                  ),
                  _ReportRow(
                    label: context.t('reportsTaskCompletionRate'),
                    value: '${(report.taskCompletionRate * 100).round()}%',
                  ),
                  _ReportRow(
                    label: context.t('reportsWeeklySurveys'),
                    value: '${report.weeklySurveysCompleted}',
                  ),
                  _ReportRow(
                    label: context.t('reportsBreathTests'),
                    value: '${report.breathTestsCompleted}',
                  ),
                  if (report.daysSinceQuitDate != null)
                    _ReportRow(
                      label: context.t('reportsDaysSinceQuit'),
                      value: '${report.daysSinceQuitDate}',
                    ),
                  if (report.totalSteps > 0) ...[
                    _ReportRow(
                      label: context.t('reportsTotalSteps'),
                      value: '${report.totalSteps}',
                    ),
                    _ReportRow(
                      label: context.t('reportsAvgStepsPerDay'),
                      value: report.avgStepsPerDay.round().toString(),
                    ),
                  ],
                  if (report.estimatedAvertedCigarettes != null)
                    _ReportRow(
                      label: context.t('reportsAvertedCigarettes'),
                      value: '${report.estimatedAvertedCigarettes}',
                    )
                  else
                    _ReportRow(
                      label: context.t('reportsAvertedCigarettes'),
                      value: context.t('reportsNoDataYet'),
                    ),
                  if (report.smokingTimePattern != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.t('reportsSmokingTimePattern'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...report.smokingTimePattern!.entries.map(
                      (entry) => _ReportRow(
                        label: context.t(
                          'reportsPart${_capitalize(entry.key)}',
                        ),
                        value: '${(entry.value * 100).round()}%',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    context.t('reportsDisclaimer'),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          if (report != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _preview,
                      child: Text(context.t('reportsPreviewButton')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _share,
                      child: Text(context.t('reportsShareButton')),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

class _ReportRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReportRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
