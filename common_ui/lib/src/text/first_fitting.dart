import 'package:flutter/widgets.dart';

/// Whether [text] fits in one line [width] wide in [style], at the text
/// size of [context].
bool fitsInLine(
  String text, {
  required double width,
  required TextStyle? style,
  required BuildContext context,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final measured = painter.width;
  painter.dispose();
  return measured <= width;
}

/// The first of [texts] that fits in one line [width] wide in [style],
/// at the text size of [context]; else the last.
String firstFitting(
  List<String> texts, {
  required double width,
  required TextStyle? style,
  required BuildContext context,
}) => texts.firstWhere(
  (text) => fitsInLine(text, width: width, style: style, context: context),
  orElse: () => texts.last,
);
