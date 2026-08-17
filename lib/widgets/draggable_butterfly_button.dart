import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Floating quick-action control. It remains a compact butterfly when idle,
/// shows the chained logo while moving, and remembers its snapped edge/height.
class DraggableButterflyButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String semanticLabel;

  const DraggableButterflyButton({
    super.key,
    required this.onPressed,
    required this.semanticLabel,
  });

  @override
  State<DraggableButterflyButton> createState() =>
      _DraggableButterflyButtonState();
}

class _DraggableButterflyButtonState extends State<DraggableButterflyButton> {
  static const _edgeKey = 'quick_butterfly_edge';
  static const _verticalKey = 'quick_butterfly_vertical';
  static const _buttonSize = 64.0;
  static const _margin = 10.0;

  bool _isDragging = false;
  bool _isRight = true;
  double? _verticalFraction;
  double? _dragLeft;

  @override
  void initState() {
    super.initState();
    _restorePosition();
  }

  Future<void> _restorePosition() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isRight = preferences.getString(_edgeKey) != 'left';
      final saved = preferences.getDouble(_verticalKey);
      _verticalFraction = saved == null ? 0.68 : saved.clamp(0.08, 0.92).toDouble();
    });
  }

  Future<void> _savePosition(double height, double top) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_edgeKey, _isRight ? 'right' : 'left');
    await preferences.setDouble(
      _verticalKey,
      (top / math.max(1, height - _buttonSize)).clamp(0.08, 0.92),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final top = (((_verticalFraction ?? 0.68) *
                    math.max(1, height - _buttonSize))
                .clamp(
                  _margin,
                  math.max(_margin, height - _buttonSize - _margin),
                ))
            .toDouble();
        final snappedLeft = _isRight
            ? math.max(_margin, width - _buttonSize - _margin)
            : _margin;
        final left = _dragLeft ?? snappedLeft;

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: _buttonSize,
              height: _buttonSize,
              child: Semantics(
                button: true,
                label: widget.semanticLabel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _isDragging ? null : widget.onPressed,
                  onPanStart: (_) => setState(() {
                    _isDragging = true;
                    _dragLeft = left;
                  }),
                  onPanUpdate: (details) {
                    final nextTop = (top + details.delta.dy).clamp(
                      _margin,
                      math.max(_margin, height - _buttonSize - _margin),
                    );
                    final nextLeft = (_dragLeft! + details.delta.dx).clamp(
                      _margin,
                      math.max(_margin, width - _buttonSize - _margin),
                    );
                    setState(() {
                      _dragLeft = nextLeft.toDouble();
                      _verticalFraction = nextTop /
                          math.max(1, height - _buttonSize);
                    });
                  },
                  onPanEnd: (_) async {
                    final centerX = (_dragLeft ?? left) + _buttonSize / 2;
                    final snappedRight = centerX >= width / 2;
                    final snappedTop = top;
                    setState(() {
                      _isRight = snappedRight;
                      _dragLeft = null;
                      _isDragging = false;
                    });
                    await _savePosition(height, snappedTop);
                  },
                  child: _ButterflyArtwork(isDragging: _isDragging),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ButterflyArtwork extends StatelessWidget {
  final bool isDragging;

  const _ButterflyArtwork({required this.isDragging});

  @override
  Widget build(BuildContext context) {
    if (isDragging) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A).withValues(alpha: 0.94),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 12, spreadRadius: 1),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Image.asset(
            'assets/images/no_smoke_logo_transparent.png',
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A).withValues(alpha: 0.94),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 10, spreadRadius: 1),
        ],
      ),
      child: ClipOval(
        child: ClipRect(
          child: Transform.translate(
            offset: const Offset(-25, 0),
            child: SizedBox(
              width: 115,
              height: 64,
              child: Image.asset(
                'assets/images/no_smoke_logo_transparent.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
