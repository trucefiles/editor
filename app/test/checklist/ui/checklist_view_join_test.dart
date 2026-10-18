import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'checklist_view_harness.dart';

/// Joining checklist items with Backspace and Delete.
void main() {
  group('joining items', () {
    testWidgets('Backspace at the start joins the item to the one above', (
      tester,
    ) async {
      final list = await showChecklist(tester, '- [ ] milk\n- [ ] eggs');
      await tester.cursorAt('eggs', 0);

      await tester.pressAndSettle(LogicalKeyboardKey.backspace);

      expect(list.text, '- [ ] milkeggs');
      expect(tester.hasFocus('milkeggs'), isTrue);
      expect(
        tester.selectionOf('milkeggs'),
        const TextSelection.collapsed(offset: 4),
      );
      await list.close();
    });

    testWidgets('Delete at the end joins the item below onto it', (
      tester,
    ) async {
      final list = await showChecklist(tester, '- [ ] milk\n- [ ] eggs');
      await tester.cursorAt('milk', 4);

      await tester.pressAndSettle(LogicalKeyboardKey.delete);

      expect(list.text, '- [ ] milkeggs');
      expect(tester.hasFocus('milkeggs'), isTrue);
      expect(
        tester.selectionOf('milkeggs'),
        const TextSelection.collapsed(offset: 4),
      );
      await list.close();
    });

    testWidgets('either key drops an empty item', (tester) async {
      final list = await showChecklist(
        tester,
        '- [ ] a\n- [ ] \n- [ ] \n- [x] b',
        separateDone: false,
      );
      await tester.cursorIn(item(1), 0);

      await tester.pressAndSettle(LogicalKeyboardKey.backspace);
      expect(list.text, '- [ ] a\n- [ ] \n- [x] b');
      expect(tester.selectionOf('a'), const TextSelection.collapsed(offset: 1));

      await tester.cursorIn(item(1), 0);
      await tester.pressAndSettle(LogicalKeyboardKey.delete);
      expect(list.text, '- [ ] a\n- [x] b', reason: 'b keeps its box');
      expect(tester.hasFocus('b'), isTrue);
      expect(tester.selectionOf('b'), const TextSelection.collapsed(offset: 0));
      await list.close();
    });

    testWidgets('either key drops an empty item with nothing to join', (
      tester,
    ) async {
      final list = await showChecklist(tester, '# T\n- [ ] \n- [ ] a\n- [ ] ');

      await tester.cursorIn(item(0), 0);
      await tester.pressAndSettle(LogicalKeyboardKey.backspace);
      expect(list.text, '# T\n- [ ] a\n- [ ] ', reason: 'below text');
      expect(tester.hasFocus('a'), isTrue, reason: 'not the top add row');

      await tester.cursorIn(item(1), 0);
      await tester.pressAndSettle(LogicalKeyboardKey.delete);
      expect(list.text, '# T\n- [ ] a', reason: 'the last item');
      expect(tester.hasFocus('Add item'), isTrue);
      await list.close();
    });

    testWidgets('drops the only item if it is empty', (tester) async {
      final list = await showChecklist(tester, '- [ ] ');

      await tester.cursorIn(item(0), 0);
      await tester.pressAndSettle(LogicalKeyboardKey.backspace);

      expect(list.text, '');
      await list.close();
    });

    testWidgets('keys inside the text edit it as usual', (tester) async {
      final list = await showChecklist(tester, '- [ ] milk\n- [ ] eggs');
      await tester.cursorAt('eggs', 2);

      await tester.pressAndPump(LogicalKeyboardKey.backspace);

      expect(list.text, '- [ ] milk\n- [ ] egs');
      await list.close();
    });

    testWidgets('nothing joins across text or past the first item', (
      tester,
    ) async {
      final list = await showChecklist(tester, '- [ ] a\n# Later\n- [ ] b');

      await tester.cursorAt('b', 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.cursorAt('a', 0);
      await tester.pressAndSettle(LogicalKeyboardKey.backspace);

      expect(list.text, '- [ ] a\n# Later\n- [ ] b');
      await list.close();
    });
  });
}
