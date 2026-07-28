import 'package:flutter/material.dart';

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

    final effectiveLabelColor =
        labelColor ?? Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: logoSize,
            height: logoSize,
            child: Image.asset(
              // The launcher artwork with its light card removed (see
              // tool/make_transparent_logo.dart). The card is right for a home
              // screen icon but reads as a pale rectangle pasted onto the
              // app's dark background. BoxFit.contain, not cover: the mark
              // sits inside its own transparent margin now, and cover would
              // crop into it.
              'assets/images/no_smoke_logo_transparent.png',
              fit: BoxFit.contain,
            ),
          ),
          if (showLabel) ...[
            const SizedBox(height: 10),
            Text(
              'NIKOTIN AWAY',
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
}
