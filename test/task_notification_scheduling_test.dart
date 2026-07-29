import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against a second scheduler creeping back in.
///
/// Two separate defects made the app feel broken in the first half hour
/// after install, and both were the same shape: something other than the
/// daily plan deciding when a task should fire.
void main() {
  final homePage = File('lib/pages/home_page.dart');

  /// Lines of real code — the file explains at length what used to be here.
  List<String> codeLines() => homePage
      .readAsLinesSync()
      .where((line) => !line.trimLeft().startsWith('//'))
      .toList();

  test('the first task is scheduled once, not three times', () {
    final source = codeLines().join('\n');
    final calls = RegExp(
      r'scheduleFirstTaskTriggerNotification\(',
    ).allMatches(source).length;

    // Registration used to call it three times for the same task — at
    // +10 min, +10 min 30 s and +15 min. One call is not one notification:
    // it schedules the alert, arms the native overlay trigger, and starts
    // the retry chain, which is two more alerts five minutes apart in a
    // different style. Three calls meant nine notifications for one task.
    //
    // The remaining call sites are: registration (once), the plan loop, the
    // SOS resume, and the mandatory-task path.
    expect(
      calls,
      lessThanOrEqualTo(5),
      reason: 'a duplicate first-task schedule has come back',
    );
  });

  test('nothing schedules tasks by offset from when the app was opened', () {
    final source = codeLines().join('\n');

    // The retired fallback spaced tasks as `base + index * gap` from
    // DateTime.now(), which is not a time of day but an offset from install:
    // a user who finished setup at nine in the evening got the whole day's
    // tasks stacked into the next ninety minutes, one after another.
    expect(
      source,
      isNot(contains('_resolveTaskNotificationDelay')),
      reason: 'the install-time-relative scheduler is back',
    );
  });

  test('the plan is the only source of task times', () {
    final lines = codeLines();
    final notifyStart = lines.indexWhere(
      (line) => line.contains('Future<void> _notifyNewTasks() async {'),
    );
    expect(notifyStart, isNot(-1));

    // Walk to the end of the method and check every scheduling call inside
    // it takes its delay from a plan item rather than an invented offset.
    var depth = 0;
    var started = false;
    final body = <String>[];
    for (var i = notifyStart; i < lines.length; i++) {
      final line = lines[i];
      depth += '{'.allMatches(line).length;
      depth -= '}'.allMatches(line).length;
      body.add(line);
      if (!started && depth > 0) started = true;
      if (started && depth == 0) break;
    }

    final joined = body.join('\n');
    expect(joined, contains('_adaptivePlanItems'));
    expect(
      joined,
      isNot(contains('for (final task in _todaysTasks)')),
      reason: 'the second scheduler loop is back in _notifyNewTasks',
    );
  });
}
