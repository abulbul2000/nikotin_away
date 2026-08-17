import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../core/app_theme.dart';

/// The "did you smoke during this time?" confirmation for a task whose
/// no-smoke window has elapsed — replaces the older `TaskOutcomeConfirmPage`
/// ("was the task completed?"), which asked the opposite-polarity question
/// and belonged to a separate, now-removed follow-up system. Large
/// Evet/Hayır buttons, not dismissible: this is the same forced-answer
/// pattern the old page used, just wired to the current TaskAssignment
/// state machine's actionId/question instead.
///
/// Pops `true` if the user smoked, `false` if they didn't — the caller
/// (NotificationService._openTaskSmokedConfirmPage) maps that to
/// TaskActionId.confirmSmokedYes/confirmSmokedNo and drives
/// TaskAssignmentService.handleTaskAction, so notification actions and this
/// body-tap-opened page both go through the same single decision point.
class TaskSmokedConfirmPage extends StatelessWidget {
  final String taskTitle;
  final String canonicalTitle;

  const TaskSmokedConfirmPage({
    super.key,
    required this.taskTitle,
    required this.canonicalTitle,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(context.t('taskConfirmQuestionTitle')),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.t('taskConfirmQuestion'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      AppTexts.localizeCanonicalText(context, taskTitle),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  height: 72,
                  child: ElevatedButton(
                    key: const ValueKey('task_smoked_confirm_yes_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(context.t('taskConfirmYesLabel')),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 72,
                  child: ElevatedButton(
                    key: const ValueKey('task_smoked_confirm_no_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandPrimary,
                      foregroundColor: Colors.black,
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(context.t('taskConfirmNoLabel')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
