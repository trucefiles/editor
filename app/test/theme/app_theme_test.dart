import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/theme/app_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    group('$brightness', () {
      final theme = appTheme(brightness);

      test('uses Inter with bold titles', () {
        expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
        expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w700);
        expect(theme.textTheme.titleMedium?.fontWeight, FontWeight.w700);
      });

      test('has shadowed cards and a flat top bar', () {
        expect(theme.colorScheme.brightness, brightness);
        expect(theme.cardTheme.elevation, greaterThan(0));
        expect(theme.appBarTheme.backgroundColor, theme.colorScheme.surface);
        expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
        expect(theme.appBarTheme.scrolledUnderElevation, greaterThan(0));
      });
    });
  }
}
