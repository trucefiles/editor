import 'package:flutter/material.dart';

/// How a note's text looks, the same in every mode, so switching modes
/// keeps its size: body text in the theme's large body style; headings
/// and code sized by the text they are in.
abstract final class NoteTextStyles {
  /// A note's body text in [theme].
  static TextStyle body(ThemeData theme) =>
      (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
        color: theme.colorScheme.onSurface,
        height: 1.4,
      );

  /// [style] as a heading of [level], 1 the largest.
  static TextStyle heading(TextStyle style, int level) => style.copyWith(
    fontWeight: FontWeight.bold,
    fontSize: sizeOf(style) * _headingScale(level),
  );

  /// [style] with every character as wide as the next.
  static TextStyle monospace(TextStyle style) =>
      style.copyWith(fontFamily: _monospace);

  /// [style] as code: monospace and, in text that isn't, a little smaller,
  /// as GitHub draws it; in monospace text as large, so columns line up.
  static TextStyle code(TextStyle style) => style.fontFamily == _monospace
      ? style
      : monospace(style).copyWith(fontSize: sizeOf(style) * 0.85);

  static double _headingScale(int level) => switch (level) {
    1 => 1.5,
    2 => 1.3,
    3 => 1.15,
    _ => 1.0,
  };

  static const _monospace = 'monospace';

  /// The font size of [style]; Flutter's own for a style that sets none.
  static double sizeOf(TextStyle style) => style.fontSize ?? 14;
}
