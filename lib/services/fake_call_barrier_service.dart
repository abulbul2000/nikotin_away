import '../pages/fake_call_page.dart';
import 'device_permission_service.dart';
import 'notification_service.dart';
import 'protocol_violation_service.dart';
import 'storage_service.dart';

/// Orchestrates the fake-call duration barrier's lifecycle: starting it on
/// answer, rescheduling on postpone/cancel (with the avoidance-streak
/// signal), and recording the final outcome. Kept separate from
/// [StorageService] (which only owns the raw persisted state) so that
/// service can stay free of a dependency on [ProtocolViolationService].
class FakeCallBarrierService {
  final StorageService _storageService;
  final ProtocolViolationService _protocolViolationService;

  static const Duration postponeDelay = Duration(minutes: 10);
  static const Duration cancelDelay = Duration(hours: 2);

  /// If the user is on a genuine phone call right when a postpone/cancel
  /// reschedule (or the day's initial scheduling — see
  /// HomePage._ensureFakeCallBarrierCadence) would otherwise fire the fake
  /// call, push it out by at least this much instead so it doesn't ring
  /// over a real conversation.
  static const Duration realCallCollisionDelay = Duration(minutes: 15);

  factory FakeCallBarrierService({
    StorageService? storageService,
    ProtocolViolationService? protocolViolationService,
  }) {
    final resolvedStorage = storageService ?? StorageService();
    return FakeCallBarrierService._(
      resolvedStorage,
      protocolViolationService ??
          ProtocolViolationService(storageService: resolvedStorage),
    );
  }

  FakeCallBarrierService._(this._storageService, this._protocolViolationService);

  /// Handles the result of a [FakeCallPage] interaction.
  Future<void> handleOutcome(FakeCallOutcome outcome) async {
    switch (outcome) {
      case FakeCallOutcome.answered:
        await NotificationService.cancelFakeCallBarrier();
        await _storageService.resetFakeCallAvoidanceStreak();
        final durationMinutes = await _storageService
            .loadFakeCallBarrierDurationMinutes();
        await _storageService.startFakeCallBarrier();
        await NotificationService.showFakeCallBarrierStartedNotification(
          duration: Duration(minutes: durationMinutes),
        );
        await _scheduleSurpriseCheckIns();
        return;
      case FakeCallOutcome.postponed:
        await _recordAvoidance();
        await NotificationService.scheduleFakeCallBarrier(
          fireAt: await _resolveFireAt(postponeDelay),
          callerName: await _storageService.loadFakeCallerName(),
        );
        return;
      case FakeCallOutcome.cancelled:
        await _recordAvoidance();
        await NotificationService.scheduleFakeCallBarrier(
          fireAt: await _resolveFireAt(cancelDelay),
          callerName: await _storageService.loadFakeCallerName(),
        );
        return;
    }
  }

  Future<void> _recordAvoidance() async {
    final streak = await _storageService.incrementFakeCallAvoidanceStreak();
    if (streak >= 3) {
      await _protocolViolationService.logFakeCallAvoided();
    }
  }

  /// `now + delay`, pushed out further if the user is on a genuine phone
  /// call right now — see [realCallCollisionDelay]. This only catches a
  /// call that's active at the moment of (re)scheduling, not one that
  /// starts later during the wait; the underlying alarm still fires
  /// unconditionally in that case.
  Future<DateTime> _resolveFireAt(Duration delay) async {
    final normal = DateTime.now().add(delay);
    if (!await DevicePermissionService.isInPhoneCall()) {
      return normal;
    }
    final afterCall = DateTime.now().add(realCallCollisionDelay);
    return afterCall.isAfter(normal) ? afterCall : normal;
  }

  /// Schedules 1-2 unpredictably-timed quiet check-ins within the active
  /// barrier window — never right at the start or end, so they don't
  /// double as a countdown reveal.
  Future<void> _scheduleSurpriseCheckIns() async {
    final endsAt = await _storageService.loadFakeCallBarrierEndsAt();
    if (endsAt == null) {
      return;
    }
    final now = DateTime.now();
    final totalMinutes = endsAt.difference(now).inMinutes;
    if (totalMinutes < 8) {
      // Too short a window for a check-in to make sense without being an
      // obvious countdown tell.
      return;
    }
    final seed = now.millisecondsSinceEpoch;
    final offsetMinutes = (totalMinutes * 0.3).round() + (seed % (totalMinutes ~/ 2).clamp(1, 999));
    final checkInAt = now.add(
      Duration(minutes: offsetMinutes.clamp(3, totalMinutes - 3)),
    );
    await NotificationService.scheduleFakeCallSurpriseCheckIn(fireAt: checkInAt);
  }

  /// Call once [StorageService.loadFakeCallBarrierEndsAt] is in the past —
  /// records the outcome the caller determined (e.g. via an "did you stay
  /// smoke-free?" prompt) and clears the barrier state either way.
  Future<void> recordOutcome({required bool succeeded}) async {
    await _storageService.recordFakeCallBarrierOutcome(succeeded: succeeded);
  }
}
