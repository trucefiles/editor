import 'package:flutter/material.dart';

/// The app-wide look for [brightness]: teal colors, Inter with bold titles,
/// shadowed cards and a flat top bar that lifts when content scrolls under.
ThemeData appTheme(Brightness brightness) {
  final base = ThemeData(
    colorSchemeSeed: Colors.teal,
    brightness: brightness,
    fontFamily: 'Inter',
  );
  final scheme = base.colorScheme;
  final text = base.textTheme.copyWith(
    titleLarge: _bold(base.textTheme.titleLarge),
    titleMedium: _bold(base.textTheme.titleMedium),
  );
  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: scheme.shadow,
      scrolledUnderElevation: 3,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    cardTheme: const CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );
}

TextStyle? _bold(TextStyle? style) =>
    style?.copyWith(fontWeight: FontWeight.w700);
