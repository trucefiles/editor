import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_editor/editor/checked_items.dart';
import 'package:truce_editor/editor/note_document_controller.dart';

import '../editor_support.dart';
import 'editor_robot.dart';

/// List rows in Visual edit: joining lines, indenting, moving and
/// deleting items.
void main() {
  DocumentPosition? caret() =>
      SuperEditorInspector.findDocumentSelection()?.extent;

  DocumentPosition at(String nodeId, int offset) => DocumentPosition(
    nodeId: nodeId,
    nodePosition: TextNodePosition(offset: offset),
  );

  /// Drags the text of item [nodeId] by [offset].
  Future<void> swipe(
    WidgetTester tester,
    String nodeId,
    Offset offset, {
    PointerDeviceKind kind = PointerDeviceKind.touch,
  }) async {
    await tester.dragFrom(tester.tapPointIn(nodeId, 0), offset, kind: kind);
    await tester.pumpAndSettle();
  }

  group('joining lines', () {
    testWidgets('Delete at the end joins the item below onto it', (
      tester,
    ) async {
      final text = FakeNoteText('- [ ] milk\n- [ ] eggs');
      await pumpNoteEditor(tester, text);
      final milk = nodeOf<TaskNode>();

      await tester.caretIn(milk, 4);
      await tester.pressDelete();

      expect(text.text, '- [ ] milkeggs');
      expect(caret(), at(milk, 4));
    });

    testWidgets('the soft keyboard joins at the start too', (tester) async {
      final text = FakeNoteText('- [ ] milk\n- [ ] eggs');
      await pumpNoteEditor(tester, text);

      await tester.caretIn(nodeOf<TaskNode>(index: 1), 0);
      await tester.ime.backspace(getter: imeClientGetter);

      expect(text.text, '- [ ] milkeggs');
    });

    testWidgets('either key drops an empty item', (tester) async {
      final text = FakeNoteText('- [ ] a\n- [ ] \n- [ ] \n- [x] b');
      await pumpNoteEditor(tester, text, checkedItems: CheckedItems.inPlace);

      await tester.caretIn(nodeOf<TaskNode>(index: 1), 0);
      await tester.pressBackspace();
      expect(text.text, '- [ ] a\n- [ ] \n- [x] b');
      expect(caret(), at(nodeOf<TaskNode>(), 1));

      await tester.caretIn(nodeOf<TaskNode>(index: 1), 0);
      await tester.pressDelete();
      expect(text.text, '- [ ] a\n- [x] b', reason: 'b keeps its box');
      expect(caret(), at(nodeOf<TaskNode>(index: 1), 0));
    });

    testWidgets('an empty item by a heading or buttons just goes away', (
      tester,
    ) async {
      final text = FakeNoteText('# T\n- [ ] \n- [ ] a');
      await pumpNoteEditor(tester, text);

      await tester.caretIn(nodeOf<TaskNode>(), 0);
      await tester.pressBackspace();

      expect(text.text, '# T\n- [ ] a');
      expect(caret(), at(nodeOf<TaskNode>(), 0));
    });

    testWidgets('keys inside the text edit it as usual', (tester) async {
      final text = FakeNoteText('- [ ] milk\n- [ ] eggs');
      await pumpNoteEditor(tester, text);

      await tester.caretIn(nodeOf<TaskNode>(index: 1), 2);
      await tester.pressBackspace();

      expect(text.text, '- [ ] milk\n- [ ] egs');
    });

    testWidgets('nothing joins across a heading', (tester) async {
      final text = FakeNoteText('- [ ] a\n# Later\n- [ ] b');
      await pumpNoteEditor(tester, text);

      await tester.caretIn(nodeOf<TaskNode>(index: 1), 0);
      await tester.pressBackspace();
      await tester.caretIn(nodeOf<TaskNode>(), 0);
      await tester.pressBackspace();

      expect(text.text, '- [ ] a\n# Later\n- [ ] b');
    });
  });

  group('indenting', () {
    testWidgets('Tab indents under the item above, Shift+Tab outdents', (
      tester,
    ) async {
      final text = FakeNoteText('- [ ] a\n- [ ] b');
      await pumpNoteEditor(tester, text);

      await tester.caretIn(nodeOf<TaskNode>(index: 1), 0);
      await tester.pressTab();
      expect(text.text, '- [ ] a\n  - [ ] b');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pressTab();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(text.text, '- [ ] a\n- [ ] b');
    });

    testWidgets('Tab indents under the open item shown above', (tester) async {
      final text = FakeNoteText('- [ ] a\n- [x] done\n- [ ] b');
      await pumpNoteEditor(tester, text);

      await tester.caretIn(nodeOf<TaskNode>(index: 1), 0);
      await tester.pressTab();

      expect(text.text, '- [ ] a\n  - [ ] b\n- [x] done');
    });

    testWidgets('without a Done section, under the checked item above', (
      tester,
    ) async {
      final text = FakeNoteText('- [ ] a\n- [x] done\n- [ ] b');
      await pumpNoteEditor(tester, text, checkedItems: CheckedItems.inPlace);

      await tester.caretIn(nodeOf<TaskNode>(index: 2), 0);
      await tester.pressTab();

      expect(text.text, '- [ ] a\n- [x] done\n  - [ ] b');
    });

    testWidgets('swiping right indents, left outdents', (tester) async {
      final text = FakeNoteText('- [ ] a\n- [ ] b');
      await pumpNoteEditor(tester, text);

      await swipe(tester, nodeOf<TaskNode>(index: 1), const Offset(100, 0));
      expect(text.text, '- [ ] a\n  - [ ] b');

      await swipe(tester, nodeOf<TaskNode>(index: 1), const Offset(-100, 0));
      expect(text.text, '- [ ] a\n- [ ] b');
    });

    testWidgets('any list row swipes, bullets and numbered items too', (
      tester,
    ) async {
      final text = FakeNoteText('- a\n- b\n1. c');
      await pumpNoteEditor(tester, text);

      await swipe(tester, nodeOf<ListItemNode>(index: 1), const Offset(100, 0));
      await swipe(tester, nodeOf<ListItemNode>(index: 2), const Offset(100, 0));

      expect(text.text, '- a\n  - b\n  1. c');
    });

    testWidgets('a long press that moves, to select text, does not indent', (
      tester,
    ) async {
      final text = FakeNoteText('- [ ] a\n- [ ] b');
      await pumpNoteEditor(tester, text);

      final gesture = await tester.startGesture(
        tester.tapPointIn(nodeOf<TaskNode>(index: 1), 0),
      );
      // A finger holding still still jitters a little.
      await gesture.moveBy(
        const Offset(1, 1),
        timeStamp: const Duration(milliseconds: 100),
      );
      final held = kLongPressTimeout + const Duration(milliseconds: 100);
      await tester.pump(held);
      await gesture.moveBy(const Offset(100, 0), timeStamp: held);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(text.edits, isEmpty);
    });

    testWidgets('a long item wraps, and a swipe on its text indents it', (
      tester,
    ) async {
      final long = 'long ' * 100;
      final text = FakeNoteText('- [ ] a\n- [ ] $long');
      await pumpNoteEditor(tester, text);

      await swipe(tester, nodeOf<TaskNode>(index: 1), const Offset(100, 0));

      expect(text.text, '- [ ] a\n  - [ ] $long');
    });

    testWidgets('a short swipe does nothing', (tester) async {
      final text = FakeNoteText('- [ ] a\n- [ ] b');
      await pumpNoteEditor(tester, text);

      await swipe(tester, nodeOf<TaskNode>(index: 1), const Offset(20, 0));

      expect(text.edits, isEmpty);
    });

    testWidgets('a mouse drag indents from the box, not the text', (
      tester,
    ) async {
      final text = FakeNoteText('- [ ] a\n- [ ] b');
      await pumpNoteEditor(tester, text);

      await swipe(
        tester,
        nodeOf<TaskNode>(index: 1),
        const Offset(100, 0),
        kind: PointerDeviceKind.mouse,
      );
      expect(text.edits, isEmpty, reason: 'selects text');

      await tester.drag(
        find.byType(Checkbox).at(1),
        const Offset(100, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(text.text, '- [ ] a\n  - [ ] b');
    });
  });

  testWidgets('dragging an item by its handle takes its subitems along', (
    tester,
  ) async {
    final text = FakeNoteText('- [ ] a\n- [ ] b\n  - [ ] sub');
    await pumpNoteEditor(tester, text);

    final handle = tester.getCenter(find.byIcon(Icons.drag_indicator).at(1));
    final above = tester.getTopLeft(find.byIcon(Icons.drag_indicator).at(0));
    final gesture = await tester.startGesture(handle);
    await tester.pump();
    await gesture.moveTo(Offset(handle.dx, above.dy + 2));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(text.text, '- [ ] b\n  - [ ] sub\n- [ ] a');
  });

  testWidgets('the menu indents an item', (tester) async {
    final text = FakeNoteText('- [ ] a\n- [ ] b');
    await pumpNoteEditor(tester, text);

    await tester.caretIn(nodeOf<TaskNode>(index: 1), 0);
    await tester.tap(find.byTooltip('Item actions').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Indent'));
    await tester.pumpAndSettle();

    expect(text.text, '- [ ] a\n  - [ ] b');
  });

  testWidgets('undoing a delete brings the item back', (tester) async {
    final text = FakeNoteText('- [ ] a\n- [ ] x\n- [ ] b');
    EditUndo? removed;
    final note = await pumpNoteEditor(
      tester,
      text,
      onRemoved: (_, undo) => removed = undo,
    );

    await tester.caretIn(nodeOf<TaskNode>(index: 1), 0);
    await tester.tap(find.byTooltip('Item actions').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(text.text, '- [ ] a\n- [ ] b');

    expect(note.undo(removed!), isTrue);
    await tester.pumpAndSettle();

    expect(text.text, '- [ ] a\n- [ ] x\n- [ ] b');
    expect(
      SuperEditorInspector.findDocument()!.whereType<TaskNode>().map(
        (node) => node.text.toPlainText(),
      ),
      ['a', 'x', 'b'],
    );
  });

  testWidgets('the Done count counts only checked items', (tester) async {
    await pumpNoteEditor(tester, FakeNoteText('- [x] a\n  - [ ] sub\n- [ ] b'));

    expect(find.text('Done (1)'), findsOneWidget);
  });
}
