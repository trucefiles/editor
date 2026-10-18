import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'checklist_view_harness.dart';

void main() {
  testWidgets('arrow keys move the cursor between items', (tester) async {
    await showChecklist(tester, '- [ ] a\n- [ ] b\n- [x] c');
    await tester.tapAndPump(field('a'));

    await tester.pressAndPump(LogicalKeyboardKey.arrowDown);
    expect(tester.hasFocus('b'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pressAndPump(LogicalKeyboardKey.arrowDown);
    expect(tester.hasFocus('c'), isTrue, reason: 'past the add row');

    await tester.pressAndPump(LogicalKeyboardKey.arrowUp);
    expect(tester.hasFocus('Add item'), isTrue);
  });

  testWidgets('the done count counts only checked items', (tester) async {
    final list = await showChecklist(tester, '- [x] a\n  - [ ] sub\n- [ ] b');

    expect(find.text('1 done'), findsOneWidget);
    await list.close();
  });

  testWidgets('shows the lines between items as Markdown', (tester) async {
    final list = await showChecklist(
      tester,
      '# Shop\n\n**Fresh** only\n- [ ] milk',
    );

    expect(find.text('Shop'), findsOne);
    expect(find.textContaining('#'), findsNothing);
    expect(find.textContaining('**'), findsNothing);
    expect(field('milk'), findsOne);
    await list.close();
  });

  testWidgets('dragging an item takes its indented text along', (tester) async {
    final list = await showChecklist(tester, '- [ ] a\n- [ ] b\n  note');

    await tester.dragHandle(
      find.byIcon(Icons.drag_indicator).at(1),
      const Offset(0, -200),
    );

    expect(list.text, '- [ ] b\n  note\n- [ ] a');
    expect(find.text('note'), findsOne);
    await list.close();
  });

  testWidgets('only the row being edited shows its menu', (tester) async {
    final list = await showChecklist(tester, '- [ ] a\n- [ ] b');
    final menus = find.byTooltip('Item actions').hitTestable();
    expect(menus, findsNothing);

    await tester.tapAndPump(field('b'));

    expect(menus, findsOneWidget);
    await tester.tapAndSettle(menus);
    await tester.tapAndSettle(find.text('Delete'));
    expect(field('b'), findsNothing);
    await list.close();
  });

  testWidgets('undo after a delete shows each line in its row', (tester) async {
    final list = await showChecklist(tester, '- [ ] a\n- [ ] b');
    await tester.tapAndPump(field('a'));
    await tester.pressEnter();
    // The fields: top add row, a, the new item, b, add row.
    await tester.enterText(find.byType(TextField).at(2), 'x');
    await tester.tapAndPump(field('x'));

    await tester.tapAndSettle(find.byTooltip('Item actions').at(1));
    await tester.tapAndSettle(find.text('Delete'));
    await tester.tapAndSettle(find.text('Undo'));

    final shown = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller!.text)
        .where((text) => text.isNotEmpty);
    expect(shown, ['a', 'x', 'b']);
    expect(list.text, '- [ ] a\n- [ ] x\n- [ ] b');
    await list.close();
  });

  testWidgets('the undo hint goes away on its own', (tester) async {
    final list = await showChecklist(tester, '- [ ] a\n- [x] b');

    await tester.tapAndPump(find.text('Clear done'));
    expect(find.text('Done items cleared'), findsOneWidget);

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Done items cleared'), findsNothing);
    await list.close();
  });
}
