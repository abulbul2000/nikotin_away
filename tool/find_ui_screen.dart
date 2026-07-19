import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
      'Usage: dart run tool/find_ui_screen.dart <catalog_json_path> <image_path_or_name>',
    );
    exit(64);
  }

  final catalogPath = args[0];
  final imageInput = args[1];

  final catalogFile = File(catalogPath);
  if (!catalogFile.existsSync()) {
    stderr.writeln('Catalog not found: $catalogPath');
    exit(66);
  }

  final catalog =
      jsonDecode(catalogFile.readAsStringSync()) as Map<String, dynamic>;
  final screens = (catalog['screens'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);

  final imageBasename = _basename(imageInput).toLowerCase();
  final imageStem = _stem(imageBasename);

  Map<String, dynamic>? matched;

  for (final screen in screens) {
    final screenshotPath = (screen['screenshotPath'] ?? '').toString();
    final screenshotName = _basename(screenshotPath).toLowerCase();
    final screenId = (screen['screenId'] ?? '').toString().toLowerCase();

    if (imageBasename == screenshotName || imageStem == screenId) {
      matched = screen;
      break;
    }
  }

  if (matched == null) {
    final candidates = <Map<String, dynamic>>[];
    final imageTokens = _tokens(imageStem);

    for (final screen in screens) {
      final score = _score(imageTokens, screen);
      if (score > 0) {
        candidates.add(<String, dynamic>{
          'score': score,
          'screenId': screen['screenId'],
          'screenName': screen['screenName'],
          'screenshotPath': screen['screenshotPath'],
        });
      }
    }

    candidates.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    final result = <String, dynamic>{
      'matched': false,
      'query': imageInput,
      'catalogPath': catalogPath,
      'suggestions': candidates.take(5).toList(growable: false),
    };

    stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
    exit(1);
  }

  final result = <String, dynamic>{
    'matched': true,
    'query': imageInput,
    'catalogPath': catalogPath,
    'screen': <String, dynamic>{
      'screenId': matched['screenId'],
      'screenName': matched['screenName'],
      'appLocation': matched['appLocation'],
      'screenshotPath': matched['screenshotPath'],
      'sourceFiles': matched['sourceFiles'],
      'uiComponents': matched['uiComponents'],
      'translationKeys': matched['translationKeys'],
      'styleSources': matched['styleSources'],
      'themeSources': matched['themeSources'],
    },
  };

  stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final parts = normalized.split('/');
  return parts.isEmpty ? normalized : parts.last;
}

String _stem(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot <= 0) {
    return filename;
  }
  return filename.substring(0, dot);
}

Set<String> _tokens(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), ' ')
      .trim()
      .toLowerCase();
  if (cleaned.isEmpty) {
    return <String>{};
  }
  return cleaned
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toSet();
}

int _score(Set<String> imageTokens, Map<String, dynamic> screen) {
  if (imageTokens.isEmpty) {
    return 0;
  }

  final tokenPool = <String>{};
  tokenPool.addAll(_tokens((screen['screenId'] ?? '').toString()));
  tokenPool.addAll(_tokens((screen['screenName'] ?? '').toString()));
  tokenPool.addAll(_tokens(_basename((screen['screenshotPath'] ?? '').toString())));

  var score = 0;
  for (final token in imageTokens) {
    if (tokenPool.contains(token)) {
      score += 1;
    }
  }
  return score;
}
