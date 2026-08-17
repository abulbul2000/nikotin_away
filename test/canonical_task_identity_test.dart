import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final notificationSource =
      File('lib/services/notification_service.dart')
          .readAsStringSync()
          .replaceAll('\r\n', '\n');
  final assignmentSource =
      File('lib/services/task_assignment_service.dart')
          .readAsStringSync()
          .replaceAll('\r\n', '\n');

  test('background task actions use canonical title for persistence and scheduling', () {
    final start = notificationSource.indexOf(
      'static Future<void> _handleActionWithoutUi',
    );
    expect(start, isNot(-1));
    final end = notificationSource.indexOf(
      '\n  /// "Tamam" logs the dose',
      start,
    );
    expect(end, greaterThan(start));
    final body = notificationSource.substring(start, end);

    expect(body, contains('taskTitle: canonicalTitle'));
    expect(body, contains('_resolveInitialTaskDelay(canonicalTitle)'));
    expect(body, contains('taskDescription: canonicalTitle'));
    expect(body, isNot(contains('taskTitle: taskTitle')));
  });

  test('foreground task actions use canonical title for timing and notifications', () {
    final start = assignmentSource.indexOf(
      'Future<TaskActionFollowUp> handleTaskAction',
    );
    expect(start, isNot(-1));
    final end = assignmentSource.indexOf(
      '\n  /// Moves the `task_assignments` row',
      start,
    );
    expect(end, greaterThan(start));
    final body = assignmentSource.substring(start, end);

    expect(body, contains('resolveInitialTaskDelay(canonicalTitle)'));
    expect(body, contains('taskDescription: canonicalTitle'));
    expect(body, contains('showPostponeChoiceNotification(\n        taskTitle: canonicalTitle'));
  });
}

