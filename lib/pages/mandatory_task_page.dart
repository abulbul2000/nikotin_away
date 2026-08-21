import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../core/app_theme.dart';
import '../services/notification_service.dart';
import '../services/task_assignment_service.dart';

/// Vertical-list task prompt — mirrors the native overlay's design
/// (TaskOverlayService.kt's showOverlay: title, body, stacked full-width
/// buttons) so the in-app screen and the (currently unused) native overlay
/// agree on one visual language instead of two. Replaces the earlier
/// incoming-call-style presentation.
///
/// This is now the ONLY way to answer a task-trigger alert — the
/// notification itself carries no actions any more, so every choice
/// (accept/decline/postpone/SOS) lives here. Pops with a [TaskActionId]
/// string, or null if the page was dismissed without a definite answer.
class MandatoryTaskPage extends StatefulWidget {
  final String taskTitle;

  const MandatoryTaskPage({super.key, required this.taskTitle});

  @override
  State<MandatoryTaskPage> createState() => _MandatoryTaskPageState();
}

class _MandatoryTaskPageState extends State<MandatoryTaskPage> {
  bool _showPostponeChoices = false;
  int _postponeCount = 0;
  int _sosCount = 0;

  @override
  void initState() {
    super.initState();
    // The task-trigger notification's alarm-stream sound loops
    // (FLAG_INSISTENT) until its notification is cancelled. Tapping the
    // notification itself already stops it (_processNotificationResponse),
    // but this page can also be reached without ever tapping it —
    // home_page.dart's _presentMandatoryTaskIfNeeded opens it on its own
    // the next time the app is foregrounded — so the alarm needs stopping
    // here too, the moment the user is actually looking at the prompt.
    NotificationService.cancelActiveTaskTriggerAlarm();
    unawaited(_loadAllowance());
  }

  Future<void> _loadAllowance() async {
    final allowance = await NotificationService.taskAllowanceFor(
      widget.taskTitle,
    );
    if (!mounted) return;
    setState(() {
      _postponeCount = allowance.$1;
      _sosCount = allowance.$2;
    });
  }

  void _pop(String actionId) {
    Navigator.of(context).pop(actionId);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Same as before: not dismissible with the back button, the user has
      // to actively answer.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.noSmokeNavy,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                Text(
                  context.t('mandatoryTaskTitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppTexts.localizeCanonicalText(context, widget.taskTitle),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 17,
                  ),
                ),
                const Spacer(flex: 3),
                if (_showPostponeChoices)
                  ..._postponeChoiceButtons()
                else
                  ..._primaryButtons(),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _primaryButtons() {
    return [
      _TaskListButton(
        key: const ValueKey('mandatory_task_start_button'),
        label: context.t('mandatoryTaskStartButton'),
        onPressed: () => _pop(TaskActionId.done),
      ),
      const SizedBox(height: 12),
      if (_postponeCount < NotificationService.maxPostponesPerTask) ...[
        _TaskListButton(
          key: const ValueKey('mandatory_task_postpone_button'),
          label: context.t('taskActionNotNowLabel'),
          onPressed: () => setState(() => _showPostponeChoices = true),
        ),
        const SizedBox(height: 12),
      ],
      _TaskListButton(
        key: const ValueKey('mandatory_task_decline_button'),
        label: context.t('mandatoryTaskDeclineButton'),
        onPressed: () => _pop(TaskActionId.decline),
      ),
      const SizedBox(height: 12),
      if (_sosCount < NotificationService.maxSosPerTask)
        _TaskListButton(
          key: const ValueKey('mandatory_task_sos_button'),
          label: context.t('cravingSosButton'),
          // Popping with the action id (rather than pushing CravingSosPage
          // from here) lets the caller apply the sosActive state transition
          // first and then open the SOS page itself — same order
          // _handleTaskNotificationAction already uses for the
          // notification-action path, so both routes into SOS agree.
          onPressed: () => _pop(TaskActionId.sos),
        ),
    ];
  }

  /// Shown in place of the primary buttons once "Ertele" is tapped — the
  /// notification used to ask this via a second, nested notification
  /// (actions can't nest), but a full-screen page has no such limit.
  List<Widget> _postponeChoiceButtons() {
    return [
      Text(
        context.t('taskActionNotNowLabel'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 20),
      _TaskListButton(
        key: const ValueKey('mandatory_task_postpone_5_button'),
        label: context.t('postpone5Label'),
        onPressed: () => _pop(TaskActionId.postpone5),
      ),
      const SizedBox(height: 12),
      _TaskListButton(
        key: const ValueKey('mandatory_task_postpone_10_button'),
        label: context.t('postpone10Label'),
        onPressed: () => _pop(TaskActionId.postpone10),
      ),
      const SizedBox(height: 12),
      _TaskListButton(
        key: const ValueKey('mandatory_task_postpone_15_button'),
        label: context.t('postpone15Label'),
        onPressed: () => _pop(TaskActionId.postpone15),
      ),
    ];
  }
}

/// Full-width, rounded, light-gray button — matches the native overlay's
/// plain Android Button styling so both surfaces read as the same prompt.
class _TaskListButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _TaskListButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEEEEEE),
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
