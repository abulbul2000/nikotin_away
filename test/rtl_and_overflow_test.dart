import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Directional-layout audit.
///
/// Arabic reads right to left, so `Alignment.centerLeft`, `TextAlign.left`
/// and `EdgeInsets.only(left:)` pin content to the physically-left edge
/// regardless of reading direction — the label ends up on the wrong side of
/// its own row. Their directional counterparts flip with the locale.
///
/// This is a source check rather than a render check on purpose: rendering
/// every screen in Arabic would catch the same thing far more slowly, and
/// only for the screens someone remembered to add.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  /// Lines of real code — comments explain what used to be here and would
  /// otherwise trip the check.
  Iterable<String> codeLines(File file) => file
      .readAsLinesSync()
      .where((line) => !line.trimLeft().startsWith('//'));

  test('no physical Alignment where reading direction matters', () {
    final offenders = <String>[];
    for (final file in dartFiles) {
      var lineNumber = 0;
      for (final line in codeLines(file)) {
        lineNumber++;
        if (RegExp(
          r'Alignment\.(center|top|bottom)(Left|Right)',
        ).hasMatch(line)) {
          offenders.add('${file.path}:$lineNumber');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Use AlignmentDirectional.centerStart/centerEnd instead: $offenders',
    );
  });

  test('no TextAlign.left or TextAlign.right', () {
    final offenders = <String>[];
    for (final file in dartFiles) {
      for (final line in codeLines(file)) {
        if (line.contains('TextAlign.left') || line.contains('TextAlign.right')) {
          offenders.add(file.path);
          break;
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Use TextAlign.start / TextAlign.end instead: $offenders',
    );
  });

  test('no EdgeInsets.only with left or right', () {
    final offenders = <String>[];
    for (final file in dartFiles) {
      final source = codeLines(file).join('\n');
      for (final match in RegExp(
        r'EdgeInsets\.only\(([^)]*)\)',
      ).allMatches(source)) {
        final args = match.group(1) ?? '';
        if (args.contains('left:') || args.contains('right:')) {
          offenders.add(file.path);
          break;
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Use EdgeInsetsDirectional.only(start:/end:) instead: $offenders',
    );
  });
}
