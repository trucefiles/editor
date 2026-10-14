import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/ui/note_sections.dart';

void main() {
  Future<void> show(
    WidgetTester tester, {
    List<String> pinned = const [],
    List<String> others = const [],
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NoteSections(
          leading: const [Text('orphan')],
          pinned: [for (final name in pinned) Text(name)],
          others: [for (final name in others) Text(name)],
        ),
      ),
    ),
  );

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  testWidgets('shows pinned cards under their own heading first', (
    tester,
  ) async {
    await show(tester, pinned: ['a'], others: ['b']);

    expect(top(tester, 'orphan'), lessThan(top(tester, 'Pinned')));
    expect(top(tester, 'Pinned'), lessThan(top(tester, 'a')));
    expect(top(tester, 'a'), lessThan(top(tester, 'Others')));
    expect(top(tester, 'Others'), lessThan(top(tester, 'b')));
  });

  testWidgets('shows no headings if nothing is pinned', (tester) async {
    await show(tester, others: ['b']);

    expect(find.text('b'), findsOne);
    expect(find.text('Pinned'), findsNothing);
    expect(find.text('Others'), findsNothing);
  });

  testWidgets('shows no "Others" heading if all are pinned', (tester) async {
    await show(tester, pinned: ['a']);

    expect(find.text('Pinned'), findsOne);
    expect(find.text('Others'), findsNothing);
  });
}
