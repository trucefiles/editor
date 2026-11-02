import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/files/file_colors.dart';

void main() {
  final light = ColorScheme.fromSeed(seedColor: Colors.teal);
  final dark = ColorScheme.fromSeed(
    seedColor: Colors.teal,
    brightness: Brightness.dark,
  );

  test('a light theme gets the pastel, a dark theme the deep tone', () {
    expect(fileTint('teal', light), fileColors['teal']!.light);
    expect(fileTint('teal', dark), fileColors['teal']!.dark);
  });

  test('no or an unknown color has no tint', () {
    expect(fileTint(null, light), isNull);
    expect(fileTint('mauve', dark), isNull);
  });

  test('pastels are light and deep tones are dark', () {
    for (final tints in fileColors.values) {
      expect(tints.light.computeLuminance(), greaterThan(0.4));
      expect(tints.dark.computeLuminance(), lessThan(0.1));
    }
  });

  test("a tinted theme's lines stand out from every tint, as text does", () {
    double contrast(Color a, Color b) {
      final (x, y) = (a.computeLuminance(), b.computeLuminance());
      return (max(x, y) + 0.05) / (min(x, y) + 0.05);
    }

    for (final scheme in [light, dark]) {
      for (final name in fileColors.keys) {
        final tint = fileTint(name, scheme)!;
        final lines = tintedTheme(ThemeData(colorScheme: scheme), tint);
        expect(
          contrast(lines.colorScheme.outlineVariant, tint),
          greaterThan(1.3),
          reason: '$name, ${scheme.brightness}',
        );
        expect(lines.dividerColor, lines.colorScheme.outlineVariant);
        expect(
          contrast(lines.colorScheme.outline, tint),
          greaterThan(contrast(lines.colorScheme.outlineVariant, tint)),
        );
      }
    }
  });
}
