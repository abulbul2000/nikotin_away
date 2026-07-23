import 'package:flutter/material.dart';

import '../core/app_texts.dart';

/// Shared error state for FutureBuilder-driven pages. Several pages used to
/// only check `snapshot.hasData` and never `snapshot.hasError`, so a failed
/// load left the user staring at a spinner forever with no way to recover
/// short of leaving and re-entering the page. This gives every such page a
/// consistent "something went wrong, try again" state with a retry button.
class LoadErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const LoadErrorView({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(context.t('loadErrorRetry'), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: Text(context.t('retry'))),
          ],
        ),
      ),
    );
  }
}
