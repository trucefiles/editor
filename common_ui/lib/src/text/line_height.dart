import 'package:flutter/widgets.dart';

/// The height of a line of text in [style] scaled by [scaler], as text
/// lays it out.
double lineHeightOf(TextStyle? style, TextScaler scaler) {
  final painter = TextPainter(
    text: TextSpan(text: ' ', style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}
