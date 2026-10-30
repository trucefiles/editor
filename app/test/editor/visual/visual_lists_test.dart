import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_core/truce_core.dart' show UndoOffered, UndoStep;
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/pinch_to_zoom.dart';
import 'package:truce_editor_test_support/truce_editor_test_support.dart';
import 'package:truce_markdown/truce_markdown.dart' show CheckedItems, Request;

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
      final text = TestDocument('- [ ] milk\n- [ ] eggs');
      await pumpDocument(tester, text);
      final milk = checkboxNodeOf();

      await tester.caretIn(milk, 4);
      await tester.pressDelete();

      expect(text.text, '- [ ] milkeggs');
      expect(caret(), at(milk, 4));
    });

    testWidgets('the soft keyboard takes the box away and joins at the start '
        'too', (tester) async {
      final text = TestDocument('- [ ] milk\n- [ ] eggs');
      await pumpDocument(tester, text);

      await tester.caretIn(checkboxNodeOf(index: 1), 0);
      await tester.ime.backspace(getter: imeClientGetter);
      expect(find.byType(Checkbox), findsOneWidget);
      await tester.ime.backspace(getter: imeClientGetter);

      expect(text.text, '- [ ] milkeggs');
    });

    testWidgets('either key drops an empty item', (tester) async {
      final text = TestDocument(
        '- [ ] a\n- [ ] \n- [ ] \n- [x] b',
        checkedItems: CheckedItems.inPlace,
      );
      await pumpDocument(tester, text);

      await tester.caretIn(checkboxNodeOf(index: 1), 0);
      await tester.pressBackspace();
      expect(text.text, '- [ ] a\n- [ ] \n- [x] b');
      expect(caret(), at(checkboxNodeOf(), 1));

      await tester.caretIn(checkboxNodeOf(index: 1), 0);
      await tester.pressDelete();
      expect(text.text, '- [ ] a\n- [x] b', reason: 'b keeps its box');
      expect(caret(), at(checkboxNodeOf(index: 1), 0));
    });

    testWidgets('an empty first item leaves the list as an empty line', (
      tester,
    ) async {
      final text = TestDocument('# T\n- [ ] \n- [ ] a');
      await pumpDocument(tester, text);

      await tester.caretIn(checkboxNodeOf(), 0);
      await tester.pressBackspace();

      expect(text.text, '# T\n- [ ] a');
      expect(caret(), at(paragraphNodeOf(index: 1), 0));
    });

    testWidgets('keys inside the text edit it as usual', (tester) async {
      final text = TestDocument('- [ ] milk\n- [ ] eggs');
      await pumpDocument(tester, text);

      await tester.caretIn(checkboxNodeOf(index: 1), 2);
      await tester.pressBackspace();

      expect(text.text, '- [ ] milk\n- [ ] egs');
    });

    testWidgets('below a heading, Backspace takes the box away first', (
      tester,
    ) async {
      final text = TestDocument('# Later\n- [ ] b');
      await pumpDocument(tester, text);

      await tester.caretIn(checkboxNodeOf(), 0);
      await tester.pressBackspace();

      expect(text.text, '# Later\n\nb');
    });
  });

  group('indenting', () {
    testWidgets('Tab indents under the item above, Shift+Tab outdents', (
      tester,
    ) async {
      final text = TestDocument('- [ ] a\n- [ ] b');
      await pumpDocument(tester, text);

      await tester.caretIn(checkboxNodeOf(index: 1), 0);
      await tester.pressTab();
      expect(text.text, '- [ ] a\n  - [ ] b');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pressTab();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(text.text, '- [ ] a\n- [ ] b');
    });

    testWidgets('Tab under a numbered item indents to its text', (
      tester,
    ) async {
      final text = TestDocument('1. a\n2. b');
      await pumpDocument(tester, text);

      await tester.caretIn(listItemNodeOf(index: 1), 0);
      await tester.pressTab();
      // A list of its own under the item, so it starts from 1.
      expect(text.text, '1. a\n   1. b');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pressTab();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(text.text, '1. a\n2. b');
    });

    testWidgets('Tab indents under the open item shown above', (tester) async {
      final text = TestDocument('- [ ] a\n- [x] done\n- [ ] b');
      await pumpDocument(tester, text);

      await tester.caretIn(checkboxNodeOf(index: 1), 0);
      await tester.pressTab();

      expect(text.text, '- [ ] a\n  - [ ] b\n- [x] done');
    });

    testWidgets('without a Done section, under the checked item above', (
      tester,
    ) async {
      final text = TestDocument(
        '- [ ] a\n- [x] done\n- [ ] b',
        checkedItems: CheckedItems.inPlace,
      );
      await pumpDocument(tester, text);

      await tester.caretIn(checkboxNodeOf(index: 2), 0);
      await tester.pressTab();

      expect(text.text, '- [ ] a\n- [x] done\n  - [ ] b');
    });

    testWidgets('swiping right indents, left outdents', (tester) async {
      final text = TestDocument('- [ ] a\n- [ ] b');
      await pumpDocument(tester, text);

      await swipe(tester, checkboxNodeOf(index: 1), const Offset(100, 0));
      expect(text.text, '- [ ] a\n  - [ ] b');

      await swipe(tester, checkboxNodeOf(index: 1), const Offset(-100, 0));
      expect(text.text, '- [ ] a\n- [ ] b');
    });

    testWidgets('any list row swipes, bullets and numbered items too', (
      tester,
    ) async {
      final text = TestDocument('- a\n- b\n\n1. c\n2. d');
      await pumpDocument(tester, text);

      await swipe(tester, listItemNodeOf(index: 1), const Offset(100, 0));
      await swipe(tester, listItemNodeOf(index: 3), const Offset(100, 0));

      expect(text.text, '- a\n  - b\n\n1. c\n   1. d');
    });

    testWidgets('a long press that moves, to select text, does not indent', (
      tester,
    ) async {
      final text = TestDocument('- [ ] a\n- [ ] b');
      await pumpDocument(tester, text);

      final gesture = await tester.startGesture(
        tester.tapPointIn(checkboxNodeOf(index: 1), 0),
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
      final text = TestDocument('- [ ] a\n- [ ] $long');
      await pumpDocument(tester, text);

      await swipe(tester, checkboxNodeOf(index: 1), const Offset(100, 0));

      expect(text.text, '- [ ] a\n  - [ ] $long');
    });

    testWidgets('a pinch over two rows swipes neither', (tester) async {
      final text = TestDocument('- [ ] a\n- [ ] b\n- [ ] c');
      var zoom = TextZoom.normal;
      await pumpDocument(
        tester,
        text,
        around: (context, child) => StatefulBuilder(
          builder: (context, setState) => PinchToZoom(
            zoom: zoom,
            onZoom: (next) => setState(() => zoom = next),
            child: child!,
          ),
        ),
      );

      final upper = tester.tapPointIn(checkboxNodeOf(), 0);
      final lower = tester.tapPointIn(checkboxNodeOf(index: 2), 0);
      final first = await tester.startGesture(upper);
      final second = await tester.startGesture(lower);
      for (final _ in Iterable<void>.generate(10)) {
        await first.moveBy(const Offset(-6, -6));
        await second.moveBy(const Offset(6, 6));
        await tester.pump();
      }
      await first.up();
      await second.up();
      await tester.pumpAndSettle();

      expect(zoom.percent, greaterThan(100));
      expect(text.edits, isEmpty);
    });

    testWidgets('a short swipe does nothing', (tester) async {
      final text = TestDocument('- [ ] a\n- [ ] b');
      await pumpDocument(tester, text);

      await swipe(tester, checkboxNodeOf(index: 1), const Offset(20, 0));

      expect(text.edits, isEmpty);
    });

    testWidgets('a mouse drag indents from the box, not the text', (
      tester,
    ) async {
      final text = TestDocument('- [ ] a\n- [ ] b');
      await pumpDocument(tester, text);

      await swipe(
        tester,
        checkboxNodeOf(index: 1),
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
    final text = TestDocument('- [ ] a\n- [ ] b\n  - [ ] sub');
    await pumpDocument(tester, text);

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

  testWidgets('while an item is dragged, its subitems fold into its copy', (
    tester,
  ) async {
    final text = TestDocument('- [ ] a\n- [ ] b\n  - [ ] s1\n  - [ ] s2');
    await pumpDocument(tester, text);
    bool shows(String text) =>
        find.text(text, findRichText: true).evaluate().isNotEmpty;

    final handle = tester.getCenter(find.byIcon(Icons.drag_indicator).at(1));
    final gesture = await tester.startGesture(handle);
    await tester.pump();
    await gesture.moveBy(const Offset(0, 20));
    await tester.pumpAndSettle();

    expect(find.text('  +2'), findsOne, reason: 'the copy counts them');
    expect(shows('s1'), isFalse);
    expect(shows('s2'), isFalse);

    await gesture.moveTo(handle);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(shows('s1'), isTrue, reason: 'shown again after the drop');
    expect(text.text, '- [ ] a\n- [ ] b\n  - [ ] s1\n  - [ ] s2');
  });

  testWidgets('on touch, the handle takes drags beside its icon too', (
    tester,
  ) async {
    final text = TestDocument('- [ ] a\n- [ ] b');
    await pumpDocument(tester, text);

    final slot = tester.getRect(find.byType(LineDragHandle).at(1));
    final icon = tester.getRect(find.byIcon(Icons.drag_indicator).at(1));
    expect(slot.width, kMinInteractiveDimension);
    final beside = Offset(slot.left + 2, icon.center.dy);
    expect(icon.contains(beside), isFalse);
    final above = tester.getTopLeft(find.byIcon(Icons.drag_indicator).at(0));
    final gesture = await tester.startGesture(beside);
    await tester.pump();
    await gesture.moveTo(Offset(beside.dx, above.dy + 2));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(text.text, '- [ ] b\n- [ ] a');
  });

  testWidgets('on touch, the handle takes drags in the gap above its icon', (
    tester,
  ) async {
    final text = TestDocument('- [ ] a\n- [ ] b');
    await pumpDocument(tester, text);

    final slot = tester.getRect(find.byType(LineDragHandle).at(0));
    final icon = tester.getRect(find.byIcon(Icons.drag_indicator).at(0));
    final gap = Offset(icon.center.dx, slot.top + 1);
    expect(gap.dy, lessThan(icon.top), reason: 'the row is taller on touch');
    final below = tester.getBottomLeft(find.byIcon(Icons.drag_indicator).at(1));
    final gesture = await tester.startGesture(gap);
    await tester.pump();
    await gesture.moveTo(Offset(gap.dx, below.dy));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(text.text, '- [ ] b\n- [ ] a');
  });

  testWidgets('dropped below an item with subitems, it lands right under it', (
    tester,
  ) async {
    final text = TestDocument('- [ ] a\n  - [ ] sub\n- [ ] b');
    await pumpDocument(tester, text);

    final handle = tester.getCenter(find.byIcon(Icons.drag_indicator).at(2));
    final target = tester.getBottomLeft(
      find.byIcon(Icons.drag_indicator).at(0),
    );
    final gesture = await tester.startGesture(handle);
    await tester.pump();
    await gesture.moveTo(Offset(handle.dx, target.dy));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(text.text, '- [ ] a\n  - [ ] b\n  - [ ] sub');
  });

  testWidgets('a first subitem dropped right below its parent stays', (
    tester,
  ) async {
    final text = TestDocument('- [ ] a\n  - [ ] sub\n- [ ] b');
    await pumpDocument(tester, text);

    final handle = tester.getCenter(find.byIcon(Icons.drag_indicator).at(1));
    final target = tester.getBottomLeft(
      find.byIcon(Icons.drag_indicator).at(0),
    );
    final gesture = await tester.startGesture(handle);
    await tester.pump();
    await gesture.moveTo(Offset(handle.dx, target.dy));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(text.text, '- [ ] a\n  - [ ] sub\n- [ ] b');
    expect(tester.takeException(), isNull);
  });

  testWidgets('dropped above a subitem, it lands as its sibling', (
    tester,
  ) async {
    final text = TestDocument('- [ ] a\n  - [ ] x\n  - [ ] y\n- [ ] b');
    await pumpDocument(tester, text);

    final handle = tester.getCenter(find.byIcon(Icons.drag_indicator).at(3));
    final target = tester.getTopLeft(find.byIcon(Icons.drag_indicator).at(1));
    final gesture = await tester.startGesture(handle);
    await tester.pump();
    await gesture.moveTo(Offset(handle.dx, target.dy + 2));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(text.text, '- [ ] a\n  - [ ] b\n  - [ ] x\n  - [ ] y');
  });

  testWidgets('the toolbar indents an item', (tester) async {
    final text = TestDocument('- [ ] a\n- [ ] b');
    await pumpDocument(tester, text);

    await tester.caretIn(checkboxNodeOf(index: 1), 0);
    await tester.tap(find.byTooltip('Indent (Tab)'));
    await tester.pumpAndSettle();

    expect(text.text, '- [ ] a\n  - [ ] b');
  });

  testWidgets('undoing a delete brings the item back', (tester) async {
    final text = TestDocument('- [ ] a\n- [ ] x\n- [ ] b');
    await pumpDocument(tester, text);

    await tester.caretIn(checkboxNodeOf(index: 1), 0);
    await tester.tap(find.byTooltip('Delete item').hitTestable());
    await tester.pumpAndSettle();
    expect(text.text, '- [ ] a\n- [ ] b');

    final removed = text.notices.whereType<UndoOffered>().single;
    text.gate.send((_) => Request(UndoStep(removed.id)));
    await tester.pumpAndSettle();

    expect(text.text, '- [ ] a\n- [ ] x\n- [ ] b');
    expect(
      SuperEditorInspector.findDocument()!
          .whereType<TextNode>()
          .where((node) => markedItemOf(node) != null)
          .map((node) => node.text.toPlainText()),
      ['a', 'x', 'b'],
    );
  });

  testWidgets('the Done count counts only checked items', (tester) async {
    await pumpDocument(tester, TestDocument('- [x] a\n  - [ ] sub\n- [ ] b'));

    expect(find.text('Done (1)'), findsOneWidget);
  });
}
