import 'package:flutter/material.dart';

/// The backgrounds of added and removed lines in a diff, as git hosts
/// show them: green and red, light or dark.
final class DiffColors {
  const DiffColors._(this.added, this.removed);

  factory DiffColors.of(Brightness brightness) => switch (brightness) {
    Brightness.light => _light,
    Brightness.dark => _dark,
  };

  static const _light = DiffColors._(Color(0xFFDAFBE1), Color(0xFFFFEBE9));
  static const _dark = DiffColors._(Color(0x332EA043), Color(0x33F85149));

  final Color added;
  final Color removed;
}
