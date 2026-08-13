import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../models/protocol_violation.dart';
import '../services/storage_service.dart';

class ProtocolViolationsPage extends StatefulWidget {
  const ProtocolViolationsPage({super.key});

  @override
  State<ProtocolViolationsPage> createState() => _ProtocolViolationsPageState();
}

class _ProtocolViolationsPageState extends State<ProtocolViolationsPage> {
  final StorageService _storageService = StorageService();
  bool _loading = true;
  List<ProtocolViolation> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await _storageService.loadProtocolViolations();
    if (!mounted) {
      return;
    }
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return Colors.redAccent;
      case 'medium':
        return Colors.orangeAccent;
      default:
        return Colors.lightGreenAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final highCount = _rows
        .where((e) => e.severity.toLowerCase() == 'high')
        .length;
    final mediumCount = _rows
        .where((e) => e.severity.toLowerCase() == 'medium')
        .length;
    final lowCount = _rows
        .where((e) => e.severity.toLowerCase() == 'low')
        .length;

    return Scaffold(
      appBar: AppBar(title: Text(context.t('violationReportTitle'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: context.t('violationHigh'),
                          value: '$highCount',
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SummaryCard(
                          label: context.t('violationMedium'),
                          value: '$mediumCount',
                          color: Colors.orangeAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SummaryCard(
                          label: context.t('violationLow'),
                          value: '$lowCount',
                          color: Colors.lightGreenAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _rows.isEmpty
                      ? Center(child: Text(context.t('violationReportEmpty')))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: _rows.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final row = _rows[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            row.type,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _severityColor(
                                              row.severity,
                                            ).withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            row.severity.toUpperCase(),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    if ((row.taskTitle ?? '').trim().isNotEmpty)
                                      Text(
                                        '${context.t('violationTask')}: ${row.taskTitle}',
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${context.t('violationSource')}: ${row.source}',
                                    ),
                                    const SizedBox(height: 4),
                                    Text(row.details),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${context.t('violationTime')}: ${_formatDate(row.createdAt)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
