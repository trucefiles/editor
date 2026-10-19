import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'checklist_view_harness.dart';

/// Adding items to a checklist: the add rows and Enter.
void main() {
  testWidgets('typing in the add row starts an item in the note', (
    tester,
  ) async {
    final list = await showChecklist(tester, '');

    await tester.enterText(field('Add item'), 'M');
    await tester.pump();

    expect(list.text, '- [ ] M\n');
    expect(list.saved, '- [ ] M\n', reason: 'saved without Enter');
    expect(tester.hasFocus('M'), isTrue, reason: 'typing goes on there');
    expect(tester.selectionOf('M'), const TextSelection.collapsed(offset: 1));
    expect(tester.typedIn('Add item'), '');

    await tester.enterText(field('M'), 'Milk');
    await tester.pump();
    expect(list.saved, '- [ ] Milk\n');
    await list.close();
  });

  testWidgets('typing in the top add row starts an item above the others', (
    tester,
  ) async {
    final list = await showChecklist(tester, '# Todo\n- [ ] a\n- [ ] b\n');

    await tester.enterText(field('Add item at top'), 'M');
    await tester.pump();

    expect(list.text, '# Todo\n- [ ] M\n- [ ] a\n- [ ] b\n');
    expect(tester.hasFocus('M'), isTrue, reason: 'typing goes on there');
    expect(tester.typedIn('Add item at top'), '');
    await list.close();
  });

  group('typing fast in an add row keeps every key', () {
    for (final (hint, before, after) in [
      ('Add item at top', '- [ ] M', '\n- [ ] a\n'),
      ('Add item', '- [ ] a\n- [ ] M', '\n'),
    ]) {
      testWidgets(hint, (tester) async {
        final list = await showChecklist(tester, '- [ ] a\n');

        // Both keys arrive before the new item's row takes the cursor.
        await tester.enterText(field(hint), 'M');
        tester.testTextInput.enterText('Mi');
        await tester.pump();
        await tester.pump();

        expect(list.text, '${before}i$after');
        expect(tester.hasFocus('Mi'), isTrue, reason: 'typing goes on there');
        expect(tester.typedIn(hint), '');
        await list.close();
      });
    }
  });

  testWidgets('Enter moves to the new item without closing the keyboard', (
    tester,
  ) async {
    final list = await showChecklist(tester, '- [ ] a\n- [ ] b');
    await tester.tapAndPump(field('a'));
    tester.testTextInput.log.clear();

    await tester.pressEnter();

    expect(list.text, '- [ ] a\n- [ ] \n- [ ] b');
    // The fields: top add row, a, the new item, b, add row.
    final added = tester.widget<TextField>(find.byType(TextField).at(2));
    expect(added.focusNode!.hasFocus, isTrue);
    expect(
      tester.testTextInput.log.map((call) => call.method),
      isNot(contains('TextInput.hide')),
    );
    await list.close();
  });

  testWidgets('without open items there is one add row', (tester) async {
    final list = await showChecklist(tester, '- [x] a');

    expect(field('Add item at top'), findsNothing);
    expect(field('Add item'), findsOneWidget);
    await list.close();
  });

  testWidgets('spaces alone in the add row start no item', (tester) async {
    final list = await showChecklist(tester, '- [ ] a');

    await tester.enterText(field('Add item'), ' ');
    await tester.pump();
    expect(list.text, '- [ ] a');

    await tester.enterText(field('Add item'), ' b');
    await tester.pump();
    expect(list.text, '- [ ] a\n- [ ] b');
    await list.close();
  });

  group('add rows', () {
    testWidgets('sit right above the first item and below the last', (
      tester,
    ) async {
      final list = await showChecklist(
        tester,
        '# Shop\nintro\n- [ ] a\n## Later\n- [ ] b\n\nnote',
      );

      final order = [
        find.text('Shop'),
        field('Add item at top'),
        field('a'),
        find.text('Later'),
        field('b'),
        field('Add item'),
        find.text('note'),
      ].map(tester.top).toList();
      expect(order, [...order]..sort());
      await list.close();
    });

    testWidgets('add where they sit', (tester) async {
      final list = await showChecklist(
        tester,
        '# Shop\n- [ ] a\n  - [ ] sub\n\nnote',
      );

      await tester.enterText(field('Add item at top'), 'T');
      await tester.pump();
      await tester.enterText(field('Add item'), 'B');
      await tester.pump();

      expect(
        list.text,
        '# Shop\n- [ ] T\n- [ ] a\n  - [ ] sub\n- [ ] B\n\nnote',
      );
      await list.close();
    });

    testWidgets('keep indented text below the last item above them', (
      tester,
    ) async {
      final list = await showChecklist(tester, '- [ ] a\n  details');

      expect(
        tester.top(find.text('details')),
        lessThan(tester.top(field('Add item'))),
      );
      await list.close();
    });

    testWidgets('go by the open items, past done ones and their text', (
      tester,
    ) async {
      final list = await showChecklist(
        tester,
        '- [x] d\n# Open\n- [ ] a\n- [x] e',
      );

      await tester.enterText(field('Add item at top'), 'T');
      await tester.pump();
      await tester.enterText(field('Add item'), 'B');
      await tester.pump();

      expect(list.text, '- [x] d\n# Open\n- [ ] T\n- [ ] a\n- [ ] B\n- [x] e');
      await list.close();
    });

    testWidgets('line up with the items', (tester) async {
      final list = await showChecklist(tester, '- [ ] a');

      expect(
        tester.getCenter(find.byIcon(Icons.add).first).dx,
        tester.getCenter(find.byType(Checkbox)).dx,
      );
      expect(
        tester.getTopLeft(field('Add item')).dx,
        tester.getTopLeft(field('a')).dx,
      );
      await list.close();
    });

    testWidgets('dragging an item to the end keeps it above the text below', (
      tester,
    ) async {
      final list = await showChecklist(tester, '- [ ] a\n- [ ] b\n\nnote');

      await tester.dragHandle(
        find.byIcon(Icons.drag_indicator).first,
        const Offset(0, 120),
      );

      expect(list.text, '- [ ] b\n- [ ] a\n\nnote');
      await list.close();
    });
  });
}
