import 'package:flutter/material.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

/// A [text] after a small [mark] (a color dot, an icon), the mark
/// centered on the text's first line. Every marked line has its mark in
/// the same column and its text starting at the same place, at any text
/// size; a line without a mark keeps its text there too.
class MarkedLine extends StatelessWidget {
  const MarkedLine({required this.text, this.mark, this.style, super.key});

  final Widget? mark;
  final String text;

  /// The text's style, on top of the surrounding one.
  final TextStyle? style;

  /// As wide as an icon, so dots and icons line up.
  static const _markWidth = 24.0;

  /// As far as a list row's text from its icon at the theme's density
  /// (Flutter's `ListTile` rule), so the text lines up with list rows.
  static double _gap(ThemeData theme) =>
      16 + theme.visualDensity.horizontal * 2;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(this.style);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _gap(Theme.of(context)),
      children: [
        SizedBox(
          width: _markWidth,
          height: lineHeightOf(style, MediaQuery.textScalerOf(context)),
          child: Center(child: mark),
        ),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}
