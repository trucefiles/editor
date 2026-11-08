import 'package:flutter/material.dart';

/// Thin, faint diagonal lines in [color] over the whole box: what is
/// likely, not known, or can't be changed here.
class Stripes extends CustomPainter {
  const Stripes(this.color);

  /// The lines over a day likely in a period.
  Stripes.likelyPeriod(ColorScheme colors)
    : this(colors.error.withValues(alpha: 0.2));

  /// The lines behind views whose events can't be moved.
  Stripes.readOnly(ColorScheme colors)
    : this(colors.onSurface.withValues(alpha: 0.06));

  final Color color;

  static const _gap = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    // Lines from bottom left to top right, one every gap, across the box.
    for (var x = -size.height; x < size.width; x += _gap) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(Stripes old) => old.color != color;
}
