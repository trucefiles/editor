import 'package:flutter/material.dart';

/// A document color's background in each theme: a soft pastel in light mode, a
/// deep muted tone in dark mode, both light or dark enough for text.
typedef DocumentTints = ({Color light, Color dark});

/// Colors offered for documents, by the name saved in the synced marks. Names
/// must never change, or documents lose their color.
const documentColors = <String, DocumentTints>{
  'red': (light: Color(0xFFF4B4B0), dark: Color(0xFF6E2A2A)),
  'orange': (light: Color(0xFFF8CB9C), dark: Color(0xFF6B4120)),
  'yellow': (light: Color(0xFFFBE7A1), dark: Color(0xFF635314)),
  'green': (light: Color(0xFFC6E3B0), dark: Color(0xFF2E5233)),
  'teal': (light: Color(0xFFAEDDD5), dark: Color(0xFF1D514C)),
  'blue': (light: Color(0xFFB4D2F3), dark: Color(0xFF26445F)),
  'purple': (light: Color(0xFFD5BFE3), dark: Color(0xFF4B3158)),
  'pink': (light: Color(0xFFF6BCD3), dark: Color(0xFF632D45)),
};

/// Background of a document colored [name] in [scheme]'s theme; `null` for no
/// or an unknown color.
Color? documentTint(String? name, ColorScheme scheme) =>
    switch (documentColors[name]) {
      final tints? => switch (scheme.brightness) {
        Brightness.light => tints.light,
        Brightness.dark => tints.dark,
      },
      null => null,
    };

/// [theme] on a document's [tint]: its line colors (separators, quote bars,
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
