import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NoSmokeLogo extends StatelessWidget {
  final double size;
  final bool showLabel;
  final Color? iconColor;
  final Color? labelColor;

  const NoSmokeLogo({
    super.key,
    this.size = 96,
    this.showLabel = false,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final logoSize = size.clamp(48, 240).toDouble();
    final effectiveIconColor = iconColor ?? Theme.of(context).colorScheme.onSurface;
    final effectiveLabelColor = labelColor ?? Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: logoSize,
            height: logoSize,
            child: SvgPicture.asset(
              'assets/images/no_smoke_logo.svg',
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(effectiveIconColor, BlendMode.srcIn),
              placeholderBuilder: (_) => _buildPlaceholder(logoSize),
            ),
          ),
          if (showLabel) ...[
            const SizedBox(height: 10),
            Text(
              'NO SMOKE',
              style: TextStyle(
                fontSize: (logoSize * 0.17).clamp(14, 28).toDouble(),
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
                color: effectiveLabelColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholder(double logoSize) {
    return SizedBox(
      width: logoSize,
      height: logoSize,
      child: Center(
        child: SizedBox(
          width: logoSize * 0.52,
          height: logoSize * 0.52,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
