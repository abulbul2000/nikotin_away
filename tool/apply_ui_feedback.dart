import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
      'Usage: dart run tool/apply_ui_feedback.dart <catalog_json_path> <feedback_json_path>',
    );
    exit(64);
  }

  final catalogPath = args[0];
  final feedbackPath = args[1];

  final catalogFile = File(catalogPath);
  final feedbackFile = File(feedbackPath);
  if (!catalogFile.existsSync()) {
    stderr.writeln('Catalog not found: $catalogPath');
    exit(66);
  }
  if (!feedbackFile.existsSync()) {
    stderr.writeln('Feedback not found: $feedbackPath');
    exit(66);
  }

  final catalog =
      jsonDecode(catalogFile.readAsStringSync()) as Map<String, dynamic>;
  final feedback =
      jsonDecode(feedbackFile.readAsStringSync()) as Map<String, dynamic>;

  final screens = (catalog['screens'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
  final screenById = <String, Map<String, dynamic>>{
    for (final screen in screens) (screen['screenId'] ?? '').toString(): screen,
  };

  final updates = (feedback['updates'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);

  final applied = <Map<String, dynamic>>[];
  final skipped = <Map<String, dynamic>>[];

  for (final update in updates) {
    final screenId = (update['screenId'] ?? '').toString();
    final filePath = (update['file'] ?? '').toString();
    final find = (update['find'] ?? '').toString();
    final replace = (update['replace'] ?? '').toString();
    final isRegex = update['isRegex'] == true;
    final caseSensitive = update['caseSensitive'] == true;

    final screen = screenById[screenId];
    if (screen == null) {
      skipped.add(<String, dynamic>{
        'screenId': screenId,
        'file': filePath,
        'reason': 'unknown_screen_id',
      });
      continue;
    }

    final sourceFiles = (screen['sourceFiles'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toSet();

    final targetFiles = filePath.trim().isEmpty
        ? sourceFiles.toList(growable: false)
        : <String>[filePath];

    if (find.isEmpty) {
      skipped.add(<String, dynamic>{
        'screenId': screenId,
        'file': filePath,
        'reason': 'empty_find_pattern',
      });
      continue;
    }

    var anyApplied = false;
    for (final targetPath in targetFiles) {
      if (!sourceFiles.contains(targetPath)) {
        skipped.add(<String, dynamic>{
          'screenId': screenId,
          'file': targetPath,
          'reason': 'file_not_in_screen_sources',
        });
        continue;
      }

      final targetFile = File(targetPath);
      if (!targetFile.existsSync()) {
        skipped.add(<String, dynamic>{
          'screenId': screenId,
          'file': targetPath,
          'reason': 'target_file_missing',
        });
        continue;
      }

      final original = targetFile.readAsStringSync();
      final updated = isRegex
          ? original.replaceAll(
              RegExp(find, caseSensitive: caseSensitive),
              replace,
            )
          : original.replaceAll(find, replace);

      if (updated == original) {
        skipped.add(<String, dynamic>{
          'screenId': screenId,
          'file': targetPath,
          'reason': 'find_pattern_not_found',
        });
        continue;
      }

      targetFile.writeAsStringSync(updated);
      anyApplied = true;

      final replaceCount = isRegex
          ? RegExp(find, caseSensitive: caseSensitive)
              .allMatches(original)
              .length
          : _countMatches(original, find);

      applied.add(<String, dynamic>{
        'screenId': screenId,
        'file': targetPath,
        'replaceCount': replaceCount,
        'isRegex': isRegex,
      });
    }

    if (!anyApplied && targetFiles.isEmpty) {
      skipped.add(<String, dynamic>{
        'screenId': screenId,
        'file': filePath,
        'reason': 'no_target_files',
      });
    }
  }

  final updatedScreenIds = applied
      .map((item) => item['screenId']?.toString() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList(growable: false);

  final changedFiles = applied
      .map((item) => item['file']?.toString() ?? '')
      .where((path) => path.isNotEmpty)
      .toSet()
      .toList(growable: false);

  final screenshotByScreenId = <String, String>{
    for (final screen in screens)
      (screen['screenId'] ?? '').toString(): (screen['screenshotPath'] ?? '')
          .toString(),
  };

  final updatedScreenshots = <Map<String, String>>[
    for (final screenId in updatedScreenIds)
      <String, String>{
        'screenId': screenId,
        'screenshotPath': screenshotByScreenId[screenId] ?? '',
      },
  ];

  final report = <String, dynamic>{
    'generatedAt': DateTime.now().toIso8601String(),
    'catalogPath': catalogPath,
    'catalogRoot': catalog['catalogRoot'],
    'screenFolder': catalog['screenFolder'],
    'feedbackPath': feedbackPath,
    'updatedScreenIds': updatedScreenIds,
    'changedFiles': changedFiles,
    'updatedScreenshots': updatedScreenshots,
    'applied': applied,
    'skipped': skipped,
  };

  final reportDir = Directory('ui_catalog/reports')
    ..createSync(recursive: true);
  final reportFile = File('${reportDir.path}/last_feedback_apply_report.json');
  reportFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(report),
  );

  stdout.writeln('Applied updates: ${applied.length}');
  stdout.writeln('Skipped updates: ${skipped.length}');
  stdout.writeln('Report: ${reportFile.path}');
}

int _countMatches(String source, String pattern) {
  var count = 0;
  var index = 0;
  while (true) {
    index = source.indexOf(pattern, index);
    if (index < 0) {
      break;
    }
    count += 1;
    index += pattern.length;
  }
  return count;
}
