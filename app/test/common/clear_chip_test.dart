import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/clear_chip.dart';

void main() {
  testWidgets('Clear is filled in the inverse colors, without the outline '
      'of the filter chips', (tester) async {
    final theme = ThemeData();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(body: ClearChip(onPressed: () {})),
      ),
    );

    final chip = tester.widget<ActionChip>(find.byType(ActionChip));
    expect(chip.backgroundColor, theme.colorScheme.inverseSurface);
    expect(chip.side, BorderSide.none);
  });
}
