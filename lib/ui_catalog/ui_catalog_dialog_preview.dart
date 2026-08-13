import 'package:flutter/material.dart';

import '../core/app_texts.dart';

class UiCatalogAlertDialogPreview extends StatelessWidget {
  final String titleKey;
  final String contentKey;
  final List<String> actionKeys;

  const UiCatalogAlertDialogPreview({
    super.key,
    required this.titleKey,
    required this.contentKey,
    required this.actionKeys,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AlertDialog(
          title: Text(context.t(titleKey)),
          content: Text(context.t(contentKey)),
          actions: [
            for (final key in actionKeys)
              TextButton(onPressed: () {}, child: Text(context.t(key))),
          ],
        ),
      ),
    );
  }
}
