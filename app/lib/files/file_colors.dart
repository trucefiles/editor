import 'package:flutter/material.dart';

import '../folders/folder_colors.dart';

/// A file color's background in each theme: a soft pastel in light mode, a
/// deep muted tone in dark mode, both light or dark enough for text; and
/// its [strong] shade, for what a file draws in its color (e.g. a
/// calendar's events), seen on both themes and on its own tints.
typedef FileTints = ({Color light, Color dark, Color strong});

/// Colors offered for files, by the name saved in the synced marks. Names
/// must never change, or files lose their color.
const fileColors = <String, FileTints>{
  'red': (
    light: Color(0xFFF4B4B0),
    dark: Color(0xFF6E2A2A),
    strong: Color(0xFFD9534F),
  ),
  'orange': (
    light: Color(0xFFF8CB9C),
    dark: Color(0xFF6B4120),
    strong: Color(0xFFE07B24),
  ),
  'yellow': (
    light: Color(0xFFFBE7A1),
    dark: Color(0xFF635314),
    strong: Color(0xFFC49A12),
  ),
  'green': (
    light: Color(0xFFC6E3B0),
    dark: Color(0xFF2E5233),
    strong: Color(0xFF4C9A3C),
  ),
  'teal': (
    light: Color(0xFFAEDDD5),
    dark: Color(0xFF1D514C),
    strong: Color(0xFF23978A),
  ),
  'blue': (
    light: Color(0xFFB4D2F3),
    dark: Color(0xFF26445F),
    strong: Color(0xFF3B78C4),
  ),
  'purple': (
    light: Color(0xFFD5BFE3),
    dark: Color(0xFF4B3158),
    strong: Color(0xFF8A58B5),
  ),
  'pink': (
    light: Color(0xFFF6BCD3),
    dark: Color(0xFF632D45),
    strong: Color(0xFFCF4F86),
  ),
};

/// Background of a file colored [name] in [scheme]'s theme; `null` for no
/// or an unknown color.
Color? fileTint(String? name, ColorScheme scheme) => switch (fileColors[name]) {
  final tints? => switch (scheme.brightness) {
    Brightness.light => tints.light,
    Brightness.dark => tints.dark,
  },
  null => null,
};

/// The color a file is shown in, for a type that draws in it: its own
/// color's strong shade if it has one ([name]), else its folder's
/// ([folder], a folder color name).
Color fileColor(String? name, {required String folder}) =>
    fileColors[name]?.strong ?? folderColor(folder);

/// [theme] on a file's [tint]: its line colors (separators, quote bars,
/// table lines) mixed from the text color onto the tint, so lines show on
/// every tint as text does.
ThemeData tintedTheme(ThemeData theme, Color tint) {
  final scheme = theme.colorScheme;
  Color line(double share) =>
      Color.alphaBlend(scheme.onSurface.withValues(alpha: share), tint);
  final outlineVariant = line(0.25);
  return theme.copyWith(
    dividerColor: outlineVariant,
    colorScheme: scheme.copyWith(
      outline: line(0.55),
      outlineVariant: outlineVariant,
    ),
  );
}
