import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/period_report.dart';

/// Renders a [PeriodReport] to PDF bytes (via the `pdf` package) and hands
/// them to the OS share sheet (via `printing`, which owns the FileProvider
/// plumbing so no native/manifest work is needed here). Takes a plain
/// string map rather than a `BuildContext` so this stays a headless
/// service — the caller (ReportsPage) resolves the localized labels once
/// via `context.t(...)`.
class PdfReportService {
  Future<void> shareReport({
    required PeriodReport report,
    required Map<String, String> labels,
  }) async {
    final bytes = await _buildPdfBytes(report: report, labels: labels);
    final periodTag = _dateTag(report.periodStart);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'no_smoke_${report.periodType}_$periodTag.pdf',
    );
  }

  Future<void> previewReport({
    required PeriodReport report,
    required Map<String, String> labels,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) => _buildPdfBytes(report: report, labels: labels),
    );
  }

  Future<Uint8List> _buildPdfBytes({
    required PeriodReport report,
    required Map<String, String> labels,
  }) async {
    final doc = pw.Document();
    final trendLabel = _trendLabel(labels);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                labels['title'] ?? 'Nikotin Away',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '${_formatDate(report.periodStart)} - ${_formatDate(report.periodEnd)}',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 20),
              _row(labels['cigarettesLogged'], '${report.cigarettesLogged}'),
              _row(
                labels['avgPerDay'],
                report.avgCigarettesPerDay.toStringAsFixed(1),
              ),
              if (report.riskScoreAtStart != null &&
                  report.riskScoreAtEnd != null)
                _row(
                  labels['riskScore'],
                  '${report.riskScoreAtStart} -> ${report.riskScoreAtEnd}',
                ),
              _row(labels['riskTrend'], trendLabel(report.riskTrend)),
              _row(labels['breathTrend'], trendLabel(report.breathTrend)),
              _row(labels['smokingTrend'], trendLabel(report.smokingTrend)),
              pw.SizedBox(height: 12),
              _row(
                labels['taskSuccess'],
                '${report.taskSuccessCount}/${report.taskSuccessCount + report.taskFailureCount}',
              ),
              _row(
                labels['taskCompletionRate'],
                '${(report.taskCompletionRate * 100).round()}%',
              ),
              _row(labels['weeklySurveys'], '${report.weeklySurveysCompleted}'),
              _row(labels['breathTests'], '${report.breathTestsCompleted}'),
              if (report.daysSinceQuitDate != null)
                _row(labels['daysSinceQuit'], '${report.daysSinceQuitDate}'),
              if (report.totalSteps > 0) ...[
                pw.SizedBox(height: 12),
                _row(labels['totalSteps'], '${report.totalSteps}'),
                _row(
                  labels['avgStepsPerDay'],
                  report.avgStepsPerDay.round().toString(),
                ),
              ],
              if (report.estimatedAvertedCigarettes != null) ...[
                pw.SizedBox(height: 12),
                _row(
                  labels['avertedCigarettes'],
                  '${report.estimatedAvertedCigarettes}',
                ),
              ],
              if (report.smokingTimePattern != null) ...[
                pw.SizedBox(height: 12),
                pw.Text(
                  labels['smokingTimePattern'] ?? 'Smoking time distribution',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                ...report.smokingTimePattern!.entries.map(
                  (entry) => _row(
                    labels['part${_capitalize(entry.key)}'] ?? entry.key,
                    '${(entry.value * 100).round()}%',
                  ),
                ),
              ],
              pw.SizedBox(height: 20),
              pw.Text(
                labels['disclaimer'] ?? '',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String Function(String) _trendLabel(Map<String, String> labels) {
    return (String trend) {
      switch (trend) {
        case 'Improving':
          return labels['trendImproving'] ?? trend;
        case 'Declining':
          return labels['trendDeclining'] ?? trend;
        default:
          return labels['trendStable'] ?? trend;
      }
    };
  }

  pw.Widget _row(String? label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label ?? '', style: const pw.TextStyle(fontSize: 12)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  String _dateTag(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
  }
}
