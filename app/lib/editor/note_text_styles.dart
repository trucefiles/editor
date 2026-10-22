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
    fontSize: _sizeOf(style) * _headingScale(level),
  );

  /// [style] as code: monospace and a little smaller than the text it is
  /// in, as GitHub draws it.
  static TextStyle code(TextStyle style) =>
      style.copyWith(fontFamily: 'monospace', fontSize: _sizeOf(style) * 0.85);

  static double _headingScale(int level) => switch (level) {
    1 => 1.5,
    2 => 1.3,
    3 => 1.15,
    _ => 1.0,
  };

  /// Flutter's size for text that sets none.
  static double _sizeOf(TextStyle style) => style.fontSize ?? 14;
}
