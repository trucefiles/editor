import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/editor/ui/list_marker.dart';

void main() {
  /// [marker] under a text scaling of [textScale].
  Future<void> show(
    WidgetTester tester,
    ListMarker marker, {
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: Center(child: marker)),
        ),
      ),
    );
  }

  const box = ListMarker(ListKind.checkbox, style: TextStyle(fontSize: 16));

  /// The width the box is drawn at, in the middle of its tap area.
  double drawnBox(WidgetTester tester) {
    final checkbox = find.byType(Checkbox);
    return tester.getRect(checkbox).width *
        Checkbox.width /
        tester.getSize(checkbox).width;
  }

  testWidgets('the box grows with the text', (tester) async {
    await show(tester, box);
    final base = drawnBox(tester);
    await show(tester, box, textScale: 2);

    expect(drawnBox(tester), base * 2);
  });

  testWidgets('a box that only shows its state has the colors of one that '
      'toggles', (tester) async {
    Future<Color?> fillOf(ListMarker marker) async {
      await show(tester, marker);
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      return checkbox.fillColor?.resolve({
        WidgetState.selected,
        if (checkbox.onChanged == null) WidgetState.disabled,
      });
    }

    final shown = await fillOf(
      const ListMarker(
        ListKind.checkbox,
        checked: true,
        style: TextStyle(fontSize: 16),
      ),
    );
    final toggled = await fillOf(
      ListMarker(
        ListKind.checkbox,
        checked: true,
        style: const TextStyle(fontSize: 16),
        onToggle: () {},
      ),
    );

    expect(shown, isNotNull);
    expect(shown, toggled);
    expect(
      shown,
      Theme.of(tester.element(find.byType(Checkbox))).colorScheme.primary,
    );
  });
}
