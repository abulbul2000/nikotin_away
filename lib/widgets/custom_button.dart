import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  final bool loading;
  final Color? color;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
    this.loading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    if (outlined) {
      return OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color ?? Colors.white,
          side: BorderSide(color: color ?? AppTheme.noSmokeGreen),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: child,
      );
    }

    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppTheme.noSmokeGreen,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: child,
    );
  }
}
