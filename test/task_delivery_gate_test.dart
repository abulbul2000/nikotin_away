import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/task_assignment.dart';
import 'package:no_smoke/services/task_delivery_gate.dart';

TaskAssignment _pending({required String id, required DateTime scheduledAt}) {
  return TaskAssignment(
    id: id,
    planDate: '2026-07-20',
    canonicalTitle: 'ADAPTIVE_NO_SMOKE:30',
    durationMinutes: 30,
    scheduledAt: scheduledAt,
    state: TaskLifecycleState.pendingDelivery,
  );
}

void main() {
  test('an empty queue delivers nothing and expires nothing', () {
    final decision = TaskDeliveryGate.decide(const []);
    expect(decision.toDeliver, isNull);
    expect(decision.toExpire, isEmpty);
  });

  test('one or two queued tasks are all kept, oldest delivered', () {
    final older = _pending(id: 'a', scheduledAt: DateTime(2026, 7, 20, 9));
    final newer = _pending(id: 'b', scheduledAt: DateTime(2026, 7, 20, 10));

    final decision = TaskDeliveryGate.decide([newer, older]);

    expect(decision.toDeliver!.id, 'a');
    expect(decision.toExpire, isEmpty);
  });

  test('a third queued task is expired, not delivered or dropped silently', () {
    final oldest = _pending(id: 'a', scheduledAt: DateTime(2026, 7, 20, 9));
    final middle = _pending(id: 'b', scheduledAt: DateTime(2026, 7, 20, 10));
    final newest = _pending(id: 'c', scheduledAt: DateTime(2026, 7, 20, 11));

    final decision = TaskDeliveryGate.decide([newest, oldest, middle]);

    expect(decision.toDeliver!.id, 'a');
    expect(decision.toExpire.map((t) => t.id), ['c']);
  });

  test('an expired task is never reported to the learning engine', () {
    // TaskLifecycleState.outcomeFor already guarantees this; asserted here
    // too so a change to that mapping is caught from the queue-limit angle
    // as well.
    expect(TaskLifecycleState.outcomeFor(TaskLifecycleState.expired), isNull);
  });
}
