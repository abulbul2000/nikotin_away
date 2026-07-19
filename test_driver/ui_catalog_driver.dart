import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final catalogRoot =
      Platform.environment['UI_CATALOG_ROOT'] ?? 'ui_catalog';
  final screenshotsDir = Directory('$catalogRoot/screens')..createSync(recursive: true);
  final catalogDir = Directory('$catalogRoot/catalog')..createSync(recursive: true);
  final reportsDir = Directory('$catalogRoot/reports')..createSync(recursive: true);

  await integrationDriver(
    onScreenshot: (String screenshotName, List<int> screenshotBytes, [Map<String, Object?>? args]) async {
      final screenshotFile = File('${screenshotsDir.path}/$screenshotName.png');
      await screenshotFile.writeAsBytes(screenshotBytes, flush: true);
      return true;
    },
    responseDataCallback: (Map<String, dynamic>? data) async {
      if (data == null) {
        return;
      }
      final raw = data['ui_catalog_json'] as String?;
      if (raw == null || raw.trim().isEmpty) {
        return;
      }

      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final catalogJsonPath = '${catalogDir.path}/screen_catalog.json';
      final merged = await _mergeCatalog(
        existingPath: catalogJsonPath,
        incoming: parsed,
      );

      final pretty = const JsonEncoder.withIndent('  ').convert(merged);
      await File(catalogJsonPath).writeAsString(pretty);

      final markdown = _buildMarkdown(merged);
      await File('${catalogDir.path}/screen_catalog.md').writeAsString(markdown);

      final runReport = <String, dynamic>{
        'generatedAt': DateTime.now().toIso8601String(),
        'catalogRoot': catalogRoot,
        'screenFolder': screenshotsDir.path,
        'catalogJson': '${catalogDir.path}/screen_catalog.json',
        'catalogMarkdown': '${catalogDir.path}/screen_catalog.md',
        'screenCount': (merged['screens'] as List<dynamic>? ?? const []).length,
        'activeLanguageCode': merged['activeLanguageCode'],
      };

      await File('${reportsDir.path}/last_capture_report.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert(runReport),
      );
    },
  );
}

Future<Map<String, dynamic>> _mergeCatalog({
  required String existingPath,
  required Map<String, dynamic> incoming,
}) async {
  final incomingScreens =
      (incoming['screens'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

  final file = File(existingPath);
  if (!file.existsSync()) {
    return incoming;
  }

  try {
    final existingRaw = await file.readAsString();
    final existing = jsonDecode(existingRaw) as Map<String, dynamic>;
    final existingScreens =
        (existing['screens'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);

    final byId = <String, Map<String, dynamic>>{};
    for (final screen in existingScreens) {
      final id = screen['screenId']?.toString();
      if (id != null && id.isNotEmpty) {
        byId[id] = screen;
      }
    }
    for (final screen in incomingScreens) {
      final id = screen['screenId']?.toString();
      if (id != null && id.isNotEmpty) {
        byId[id] = screen;
      }
    }

    final mergedScreens = byId.values.toList(growable: false)
      ..sort((a, b) =>
          (a['screenId']?.toString() ?? '').compareTo(b['screenId']?.toString() ?? ''));

    return <String, dynamic>{
      'generatedAt': incoming['generatedAt'],
      'activeLanguageCode': incoming['activeLanguageCode'] ?? existing['activeLanguageCode'],
      'catalogRoot': incoming['catalogRoot'] ?? existing['catalogRoot'],
      'screenFolder': incoming['screenFolder'] ?? existing['screenFolder'],
      'catalogFile': incoming['catalogFile'] ?? existing['catalogFile'],
      'screens': mergedScreens,
    };
  } catch (_) {
    return incoming;
  }
}

String _buildMarkdown(Map<String, dynamic> catalog) {
  final buffer = StringBuffer();
  final screens = (catalog['screens'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);

  buffer.writeln('# UI Screen Catalog');
  buffer.writeln();
  buffer.writeln('- generatedAt: ${catalog['generatedAt']}');
  buffer.writeln('- activeLanguageCode: ${catalog['activeLanguageCode']}');
  buffer.writeln('- screenFolder: ${catalog['screenFolder']}');
  buffer.writeln('- catalogFile: ${catalog['catalogFile']}');
  buffer.writeln();
  buffer.writeln('| Screen ID | Screen Name | App Location | Screenshot | Sources | Components | Translation Keys | Style Sources | Theme Sources |');
  buffer.writeln('|---|---|---|---|---|---|---|---|---|');

  for (final screen in screens) {
    final sources = (screen['sourceFiles'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .join('<br>');
    final components = (screen['uiComponents'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .join('<br>');
    final translationKeys =
        (screen['translationKeys'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .join('<br>');
    final styleSources = (screen['styleSources'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .join('<br>');
    final themeSources = (screen['themeSources'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .join('<br>');
    buffer.writeln(
      '| ${screen['screenId']} | ${screen['screenName']} | ${screen['appLocation']} | ${screen['screenshotPath']} | $sources | $components | $translationKeys | $styleSources | $themeSources |',
    );
  }

  return buffer.toString();
}
