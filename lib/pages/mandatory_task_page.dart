import 'package:flutter/material.dart';

import '../core/app_texts.dart';

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
