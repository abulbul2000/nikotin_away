import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import 'craving_sos_page.dart';

class MandatoryTaskPage extends StatelessWidget {
  final String taskTitle;

  const MandatoryTaskPage({super.key, required this.taskTitle});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(context.t('mandatoryTaskTitle')),
        ),
        // A mandatory "don't smoke" command is exactly the moment a real
        // craving is most likely to hit — the SOS breathing helper needs
        // to be reachable from right here, not just from the home screen.
        // Pushed (not popped) so answering the command is unaffected.
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('mandatory_task_sos_button'),
          backgroundColor: Colors.redAccent,
          icon: const Icon(Icons.sos),
          label: Text(context.t('cravingSosButton')),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CravingSosPage()),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.t('mandatoryTaskCommand'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
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
                const SizedBox(height: 18),
                Text(
                  context.t('mandatoryTaskHint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(context.t('mandatoryTaskStartButton')),
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
