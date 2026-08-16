import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/app_texts.dart';
import '../services/app_share_service.dart';
import '../services/language_service.dart';

/// Opens the in-app social sharing preview before the platform share sheet.
Future<bool> showShareAppSheet(BuildContext context) async {
  final languageCode = await LanguageService.loadSelectedLanguageCode();
  if (!context.mounted) return false;

  final shouldShare = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _ShareAppSheet(languageCode: languageCode),
  );

  if (shouldShare == true && context.mounted) {
    await AppShareService.shareApp(languageCode: languageCode);
    return true;
  }
  return false;
}

class _ShareAppSheet extends StatelessWidget {
  final String languageCode;

  const _ShareAppSheet({required this.languageCode});

  @override
  Widget build(BuildContext context) {
    final title = AppTexts.textForCode(languageCode, 'shareAppTitle');
    final message = AppTexts.textForCode(languageCode, 'shareAppMessage');
    final shareLabel = AppTexts.textForCode(languageCode, 'shareProgressAction');
    final closeLabel = AppTexts.textForCode(languageCode, 'shareProgressSkip');

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: AppTheme.brandPrimary.withValues(alpha: 0.28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.brandPrimary.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.share_outlined,
                color: AppTheme.brandPrimary,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message.split('\n').first,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ShareTarget(
                  label: 'WhatsApp',
                  icon: Icons.chat_rounded,
                  color: const Color(0xFF25D366),
                  onTap: () => Navigator.of(context).pop(true),
                ),
                _ShareTarget(
                  label: 'Instagram',
                  icon: Icons.camera_alt_rounded,
                  color: const Color(0xFFE1306C),
                  onTap: () => Navigator.of(context).pop(true),
                ),
                _ShareTarget(
                  label: 'Facebook',
                  icon: Icons.facebook_rounded,
                  color: const Color(0xFF1877F2),
                  onTap: () => Navigator.of(context).pop(true),
                ),
                _ShareTarget(
                  label: 'X',
                  icon: Icons.close_rounded,
                  color: Colors.white,
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.ios_share_outlined),
                label: Text(shareLabel),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(closeLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareTarget extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ShareTarget({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 62,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.55)),
              ),
              child: Icon(icon, color: color, size: 25),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
