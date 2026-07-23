import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../models/survey_record.dart';
import '../services/storage_service.dart';
import '../widgets/load_error_view.dart';

class HealthMetricsPage extends StatefulWidget {
  final String name;

  const HealthMetricsPage({super.key, required this.name});

  @override
  State<HealthMetricsPage> createState() => _HealthMetricsPageState();
}

class _HealthMetricsPageState extends State<HealthMetricsPage> {
  final StorageService _storageService = StorageService();
  List<SurveyRecord> _breathTests = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadBreathTests();
  }

  Future<void> _loadBreathTests() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final history = await _storageService.loadSurveyHistory();
      final breathTests = history.where((r) => r.type == 'breath_test').toList()
        ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

      if (!mounted) return;
      setState(() {
        _breathTests = breathTests;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  String _calculateTrend(List<int> values) {
    if (values.length < 2) return 'N/A';
    final firstHalf = values.take((values.length / 2).ceil()).toList();
    final secondHalf = values.skip((values.length / 2).ceil()).toList();

    final avgFirst = firstHalf.isEmpty
        ? 0
        : firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final avgSecond = secondHalf.isEmpty
        ? 0
        : secondHalf.reduce((a, b) => a + b) / secondHalf.length;

    final improvement = ((avgSecond - avgFirst) / avgFirst * 100)
        .toStringAsFixed(1);
    return improvement;
  }

  Widget _buildMetricCard(String title, String value, String subtitle) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('healthMetrics'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? LoadErrorView(onRetry: _loadBreathTests)
          : _breathTests.isEmpty
          ? Center(
              child: Text(
                context.t('noBreathTestsYet'),
                style: const TextStyle(fontSize: 16),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('longitudinalAnalysis'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Exhale trend
                  _buildMetricCard(
                    context.t('exhaleCapacity'),
                    '${_breathTests.last.exhaleTestSeconds}s',
                    '${context.t('trendLabel')}: ${_calculateTrend(_breathTests.map((r) => r.exhaleTestSeconds).toList())}%',
                  ),
                  // Inhale trend
                  _buildMetricCard(
                    context.t('inhaleCapacity'),
                    '${_breathTests.last.inhaleTestSeconds}s',
                    '${context.t('trendLabel')}: ${_calculateTrend(_breathTests.map((r) => r.inhaleTestSeconds).toList())}%',
                  ),
                  // Risk score trend
                  _buildMetricCard(
                    context.t('riskScore'),
                    '${_breathTests.last.riskScore}/100',
                    '${context.t('levelLabel')}: ${_breathTests.last.riskLevel}',
                  ),
                  const SizedBox(height: 24),
                  // Statistics
                  Text(
                    context.t('statistics'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMetricCard(
                    context.t('totalTestCount'),
                    '${_breathTests.length}',
                    '${context.t('firstTestDate')}: ${_breathTests.first.completedAt.day}/${_breathTests.first.completedAt.month}/${_breathTests.first.completedAt.year}',
                  ),
                  _buildMetricCard(
                    context.t('averageExhale'),
                    '${(_breathTests.map((r) => r.exhaleTestSeconds).reduce((a, b) => a + b) / _breathTests.length).toStringAsFixed(1)}s',
                    '${context.t('minLabel')}: ${_breathTests.map((r) => r.exhaleTestSeconds).reduce((a, b) => a < b ? a : b)}s, ${context.t('maxLabel')}: ${_breathTests.map((r) => r.exhaleTestSeconds).reduce((a, b) => a > b ? a : b)}s',
                  ),
                  _buildMetricCard(
                    context.t('averageInhale'),
                    '${(_breathTests.map((r) => r.inhaleTestSeconds).reduce((a, b) => a + b) / _breathTests.length).toStringAsFixed(1)}s',
                    '${context.t('minLabel')}: ${_breathTests.map((r) => r.inhaleTestSeconds).reduce((a, b) => a < b ? a : b)}s, ${context.t('maxLabel')}: ${_breathTests.map((r) => r.inhaleTestSeconds).reduce((a, b) => a > b ? a : b)}s',
                  ),
                  const SizedBox(height: 24),
                  // Recent tests
                  Text(
                    context.t('recentTests'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._breathTests.reversed.take(10).map((test) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${test.completedAt.day}/${test.completedAt.month}/${test.completedAt.year}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${context.t('exhaleLabel')}: ${test.exhaleTestSeconds}s | ${context.t('inhaleLabel')}: ${test.inhaleTestSeconds}s',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            Text(
                              AppTexts.localizeCanonicalText(
                                context,
                                test.riskLevel,
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _riskColor(test.riskLevel),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  // Export button (placeholder)
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.t('exportComingSoon')),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download),
                      label: Text(context.t('exportPDF')),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Color _riskColor(String level) {
    switch (level.toUpperCase()) {
      case 'LOW':
        return Colors.green;
      case 'MEDIUM':
        return Colors.orange;
      case 'HIGH':
        return Colors.red;
      case 'CRITICAL':
        return Colors.red[900] ?? Colors.red;
      default:
        return Colors.grey;
    }
  }
}
