import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../core/app_theme.dart';

/// Forces an answer for a task whose follow-up is due — large Evet/Hayır
/// buttons, not dismissible, no third "later" option here (unlike the
/// in-app follow-up list this replaces as the primary path): the point is
/// that a due follow-up can no longer be silently skipped by leaving the
/// app or swiping a notification away.
class TaskOutcomeConfirmPage extends StatelessWidget {
  final String taskTitle;

  const TaskOutcomeConfirmPage({super.key, required this.taskTitle});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(context.t('taskFollowUpTitle')),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.t('taskOutcomeConfirmQuestion'),
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
                    key: const ValueKey('task_outcome_yes_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandPrimary,
                      foregroundColor: Colors.black,
                      textStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(context.t('yes')),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 72,
                  child: ElevatedButton(
                    key: const ValueKey('task_outcome_no_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      textStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(context.t('no')),
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
