import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../core/app_theme.dart';
import '../models/daily_progress_report.dart';
import '../services/storage_service.dart';

/// The pre-sleep routine's final step: a same-day summary pulled together by
/// `StorageService.buildDailyProgressReport`. Reuses the metric-column
/// layout HomePage's reduction card already established (big number + unit
/// + label) rather than inventing a new visual language for one screen.
class DailyProgressReportView extends StatefulWidget {
  final StorageService storageService;
  final VoidCallback onClose;

  const DailyProgressReportView({
    super.key,
    required this.storageService,
    required this.onClose,
  });

  @override
  State<DailyProgressReportView> createState() =>
      _DailyProgressReportViewState();
}

class _DailyProgressReportViewState extends State<DailyProgressReportView> {
  DailyProgressReport? _report;
  String? _sleepTime;
  String? _wakeTime;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final report = await widget.storageService.buildDailyProgressReport();
    final fallbackSleep = await widget.storageService.loadSleepTime() ?? '23:00';
    final fallbackWake =
        await widget.storageService.loadSetting('wake_time') ?? '07:00';
    final sleepWindow = await widget.storageService.resolveEffectiveSleepWindow(
      fallbackSleepTime: fallbackSleep,
      fallbackWakeTime: fallbackWake,
    );
    if (!mounted) return;
    setState(() {
      _report = report;
      _sleepTime = sleepWindow.sleepTime ?? fallbackSleep;
      _wakeTime = sleepWindow.wakeTime ?? fallbackWake;
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    const accent = Colors.teal;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t('sleepRoutineReportTitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: report == null
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildSleepSummary(context, accent),
                          const SizedBox(height: 12),
                          _buildReportCard(context, report, accent),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: widget.onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                ),
                child: Text(context.t('sleepRoutineReportCloseButton')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepSummary(BuildContext context, Color accent) {
    final sleep = _parseClock(_sleepTime);
    final wake = _parseClock(_wakeTime);
    final duration = sleep == null || wake == null
        ? null
        : ((wake - sleep + 24 * 60) % (24 * 60));
    final durationText = duration == null
        ? '—'
        : '${duration ~/ 60}s ${duration % 60}dk';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF153B3B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withAlpha(180)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t('sleepIntelligenceTitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _sleepMetric(context.t('sleepTime'), _sleepTime ?? '—', accent),
              _sleepMetric(context.t('wakeTime'), _wakeTime ?? '—', accent),
              _sleepMetric('Uyku süresi', durationText, accent),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Bu özet gece boyunca öğrenilen ekran ve şarj sinyallerine göre hazırlandı.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: accent.withAlpha(220)),
          ),
        ],
      ),
    );
  }

  Widget _sleepMetric(String label, String value, Color accent) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: accent.withAlpha(220)),
          ),
        ],
      ),
    );
  }

  int? _parseClock(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  Widget _buildReportCard(
    BuildContext context,
    DailyProgressReport report,
    Color accent,
  ) {
    final progress = report.reductionProgress;
    if (!progress.hasEvidence) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: accent.withAlpha((255 * 0.2).toInt()),
          border: Border.all(color: accent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          context.t('sleepRoutineReportNoEvidence'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: accent.withAlpha((255 * 0.9).toInt()),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent.withAlpha((255 * 0.2).toInt()),
        border: Border.all(color: accent, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _metric(
                  value: '${progress.targetStreakDays}',
                  unit: context.t('dayUnit'),
                  label: context.t('reductionStreakLabel'),
                  accent: accent,
                ),
              ),
              Expanded(
                child: _metric(
                  value: '${progress.cigarettesAvoided}',
                  unit: context.t('cigaretteUnit'),
                  label: context.t('reductionAvoidedLabel'),
                  accent: accent,
                ),
              ),
              Expanded(
                child: _metric(
                  value: '${(report.taskSuccessRateLast7Days * 100).round()}',
                  unit: '%',
                  label: context.t('sleepRoutineReportTaskSuccessLabel'),
                  accent: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            context
                .t('reductionTargetToday')
                .replaceAll('{target}', '${progress.dailyTarget}'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context
                .t('reductionLoggedToday')
                .replaceAll('{count}', '${report.todaySmokedCount}'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: accent.withAlpha((255 * 0.85).toInt()),
            ),
          ),
          if (report.latestCoughTest != null) ...[
            const SizedBox(height: 10),
            Text(
              context
                  .t('coughTestResultCount')
                  .replaceAll(
                    '{count}',
                    '${report.latestCoughTest!.coughCount}',
                  ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: accent.withAlpha((255 * 0.85).toInt()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric({
    required String value,
    required String unit,
    required String label,
    required Color accent,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: accent,
          ),
        ),
        Text(unit, style: TextStyle(fontSize: 12, color: accent)),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            height: 1.25,
            color: accent.withAlpha((255 * 0.9).toInt()),
          ),
        ),
      ],
    );
  }
}
