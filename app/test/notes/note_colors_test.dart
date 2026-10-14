import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/note_colors.dart';

void main() {
  final light = ColorScheme.fromSeed(seedColor: Colors.teal);
  final dark = ColorScheme.fromSeed(
    seedColor: Colors.teal,
    brightness: Brightness.dark,
  );

  test('a light theme gets the pastel, a dark theme the deep tone', () {
    expect(noteTint('teal', light), noteColors['teal']!.light);
    expect(noteTint('teal', dark), noteColors['teal']!.dark);
  });

  test('no or an unknown color has no tint', () {
    expect(noteTint(null, light), isNull);
    expect(noteTint('mauve', dark), isNull);
  });

  test('pastels are light and deep tones are dark', () {
    for (final tints in noteColors.values) {
      expect(tints.light.computeLuminance(), greaterThan(0.4));
      expect(tints.dark.computeLuminance(), lessThan(0.1));
    }
  });
}
