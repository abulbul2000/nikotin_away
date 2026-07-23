import '../engines/mentor_message_builder.dart';
import 'storage_service.dart';

/// Centralizes the "what happened → which protocol-violation type/severity"
/// decision that used to be duplicated ad hoc at each call site across
/// home_page.dart and task_follow_up_page.dart (raw `saveProtocolViolation`
/// calls with inline type/severity/details strings, no test coverage). Each
/// scenario now has one named, testable entry point here instead.
///
/// Every logged violation (except the purely informational "mandatory
/// screen was shown" one) also generates a reframed [MentorMessageBuilder]
/// message — the discipline-protocol bookkeeping keeps running underneath,
/// but the user-facing voice is the supportive mentor, not a bare
/// "violation recorded" alert.
class ProtocolViolationService {
  final StorageService _storageService;
  final MentorMessageBuilder _mentorMessageBuilder;

  ProtocolViolationService({
    StorageService? storageService,
    MentorMessageBuilder? mentorMessageBuilder,
  }) : _storageService = storageService ?? StorageService(),
       _mentorMessageBuilder = mentorMessageBuilder ?? MentorMessageBuilder();

  Future<void> _reframe(String violationType, String? taskTitle) async {
    final message = _mentorMessageBuilder.buildReframedViolationMessage(
      violationType: violationType,
      taskTitle: taskTitle,
    );
    if (message != null) {
      await _storageService.saveMentorMessage(message);
    }
  }

  /// Motion/usage sensor spikes detected during an active task's timer.
  Future<void> logSuspiciousBehavior({required String taskTitle}) async {
    await _storageService.saveProtocolViolation(
      type: 'suspicious_behavior',
      severity: 'high',
      source: 'app_flow',
      taskTitle: taskTitle,
      details:
          'Suspicious movement/usage detected during active task timer. Timer reset.',
    );
    await _reframe('suspicious_behavior', taskTitle);
  }

  /// User answered "no" when asked whether they completed a task.
  Future<void> logWillpowerWeakness({required String taskTitle}) async {
    await _storageService.saveProtocolViolation(
      type: 'willpower_weakness',
      severity: 'medium',
      source: 'app_flow',
      taskTitle: taskTitle,
      details: 'Task outcome marked as not completed by user.',
    );
    await _reframe('willpower_weakness', taskTitle);
  }

  /// User tapped "not now" on a task notification.
  Future<void> logDeferredStart({required String taskTitle}) async {
    await _storageService.saveProtocolViolation(
      type: 'deferred_start',
      severity: 'medium',
      source: 'app_flow',
      taskTitle: taskTitle,
      details: 'User deferred task start for 10 minutes.',
    );
    await _reframe('deferred_start', taskTitle);
  }

  /// User deferred a follow-up check-in rather than answering it.
  Future<void> logFollowUpDeferred({
    required String taskTitle,
    String details = 'Follow-up response deferred for 10 minutes.',
  }) async {
    await _storageService.saveProtocolViolation(
      type: 'followup_deferred',
      severity: 'low',
      source: 'app_flow',
      taskTitle: taskTitle,
      details: details,
    );
    await _reframe('followup_deferred', taskTitle);
  }

  /// User marked a smoke-free duration barrier as failed once its timer ended.
  Future<void> logDurationBarrierFailure({required String command}) async {
    await _storageService.saveProtocolViolation(
      type: 'duration_barrier_failure',
      severity: 'medium',
      source: 'app_flow',
      taskTitle: command,
      details: 'User marked smoke-free duration as failed after timer end.',
    );
    await _reframe('duration_barrier_failure', command);
  }

  /// The mandatory task screen was shown on app open. Purely informational
  /// (not a user behavior to reframe), so no mentor message is generated.
  Future<void> logMandatoryGateShown({required String taskTitle}) {
    return _storageService.saveProtocolViolation(
      type: 'mandatory_gate',
      severity: 'medium',
      source: 'app_flow',
      taskTitle: taskTitle,
      details: 'Mandatory task screen displayed on app open.',
    );
  }

  /// The user has repeatedly postponed/cancelled the fake-call duration
  /// barrier without ever answering it (3+ in a row) — an avoidance
  /// pattern worth surfacing rather than passing silently.
  Future<void> logFakeCallAvoided() async {
    await _storageService.saveProtocolViolation(
      type: 'fake_call_avoided',
      severity: 'medium',
      source: 'app_flow',
      taskTitle: null,
      details: 'User postponed/cancelled the fake-call barrier 3+ times in a row.',
    );
    await _reframe('fake_call_avoided', null);
  }

  /// A dedicated follow-up screen was answered as "smoked" / unsuccessful.
  Future<void> logFollowUpFailed({required String taskTitle}) async {
    await _storageService.saveProtocolViolation(
      type: 'followup_failed',
      severity: 'medium',
      source: 'app_flow',
      taskTitle: taskTitle,
      details: 'Task follow-up marked as unsuccessful.',
    );
    await _reframe('followup_failed', taskTitle);
  }
}
