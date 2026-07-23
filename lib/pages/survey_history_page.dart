import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../models/survey_record.dart';
import '../services/storage_service.dart';
import '../widgets/load_error_view.dart';

class SurveyHistoryPage extends StatefulWidget {
  const SurveyHistoryPage({super.key});

  @override
  State<SurveyHistoryPage> createState() => _SurveyHistoryPageState();
}

class _SurveyHistoryPageState extends State<SurveyHistoryPage> {
  final StorageService _storageService = StorageService();
  late Future<List<SurveyRecord>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _storageService.loadSurveyHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('surveyHistory'))),
      body: FutureBuilder<List<SurveyRecord>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return LoadErrorView(
              onRetry: () {
                setState(() {
                  _historyFuture = _storageService.loadSurveyHistory();
                });
              },
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data!;
          if (records.isEmpty) {
            return Center(child: Text(context.t('noSurveyYet')));
          }

          // loadSurveyHistory() returns oldest-first; a "history" list
          // reads most naturally newest-first.
          final reversedRecords = records.reversed.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reversedRecords.length,
            itemBuilder: (context, index) {
              final record = reversedRecords[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    record.name.isEmpty
                        ? context.t('unnamedUser')
                        : record.name,
                  ),
                  subtitle: Text(
                    '${record.title} • ${record.completedAt.day}/${record.completedAt.month}/${record.completedAt.year} • ${context.t('risk')}: ${record.riskScore} • ${AppTexts.localizeCanonicalText(context, record.riskLevel)}',
                  ),
                  trailing: const Icon(Icons.history),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
