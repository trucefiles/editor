import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_core/truce_core.dart' show UndoOffered, UndoStep;
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_editor_test_support/truce_editor_test_support.dart';
import 'package:truce_markdown/truce_markdown.dart'
    show CheckedItems, EditMode, Request, SetMode;

/// Editing a document in Visual edit.
void main() {
  testWidgets('typing in an item changes only its line', (tester) async {
    final document = TestDocument('# Shop\n- [ ] milk\n- [ ] eggs');
    await pumpDocument(tester, document);

    await tester.caretIn(checkboxNodeOf(), 4);
    await tester.typeImeText(' oat');

    expect(document.text, '# Shop\n- [ ] milk oat\n- [ ] eggs');
  });

  testWidgets('Enter at the end of an item starts the next one', (
    tester,
  ) async {
    final document = TestDocument('- [ ] milk\n1. one');
    await pumpDocument(tester, document);

    await tester.caretIn(checkboxNodeOf(), 4);
    await tester.pressEnter();
    await tester.typeImeText('eggs');
    await tester.caretIn(listItemNodeOf(), 3);
    await tester.pressEnter();
    await tester.typeImeText('two');

    expect(document.text, '- [ ] milk\n- [ ] eggs\n1. one\n2. two');
  });

  testWidgets('Backspace at the start of an item takes its box away, then '
      'joins it to the one above', (tester) async {
    final document = TestDocument('- [ ] milk\n- [ ] eggs');
    await pumpDocument(tester, document);

    await tester.caretIn(checkboxNodeOf(index: 1), 0);
    await tester.pressBackspace();
    expect(find.byType(Checkbox), findsOneWidget);
    await tester.pressBackspace();

    expect(document.text, '- [ ] milkeggs');
  });

  testWidgets('tapping the box checks the item', (tester) async {
    final document = TestDocument('- [ ] milk\n- [ ] eggs');
    await pumpDocument(tester, document);

    await tester.tap(find.byType(Checkbox).first);
    await tester.boxTapsSent(document);

    expect(document.text, '- [x] milk\n- [ ] eggs');
    expect(find.text('Done (1)'), findsOneWidget);
  });

  testWidgets('the Done heading folds its items away', (tester) async {
    final document = TestDocument('- [ ] milk\n- [x] eggs');
    await pumpDocument(tester, document);
    expect(find.byType(Checkbox), findsNWidgets(2));

    await tester.tap(find.text('Done (1)'));
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsOneWidget);
    expect(document.edits, isEmpty);
  });

  testWidgets('Add item adds an item of the list\'s kind for typing', (
    tester,
  ) async {
    final document = TestDocument('- [ ] milk');
    await pumpDocument(tester, document);

    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.typeImeText('eggs');

    expect(document.text, '- [ ] eggs\n- [ ] milk');
  });

  testWidgets('Add item at the bottom, with "Move to end", adds above the '
      'checked items', (tester) async {
    final document = TestDocument(
      '- [ ] milk\n- [x] tea',
      checkedItems: CheckedItems.moveToEnd,
    );
    await pumpDocument(tester, document, addItems: AddItemPlace.bottom);

    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.typeImeText('eggs');

    expect(document.text, '- [ ] milk\n- [ ] eggs\n- [x] tea');
  });

  testWidgets('the delete button of the edited row deletes its item, '
      'which can be undone', (tester) async {
    final document = TestDocument('- [ ] milk\n- [ ] eggs');
    await pumpDocument(tester, document);

    await tester.caretIn(checkboxNodeOf(), 0);
    final delete = find.byTooltip('Delete item').hitTestable();
    expect(delete, findsOneWidget, reason: 'only the edited row has one');
    await tester.tap(delete);
    await tester.pumpAndSettle();

    expect(document.text, '- [ ] eggs');
    final removed = document.notices.whereType<UndoOffered>().single;
    document.gate.send((_) => Request(UndoStep(removed.id)));
    await tester.pumpAndSettle();
    expect(document.text, '- [ ] milk\n- [ ] eggs');
  });

  group('a separator item', () {
    const shop = '- [ ] milk\n- [ ] ------\n- [ ] eggs';

    testWidgets('has a drag handle like every item', (tester) async {
      await pumpDocument(tester, TestDocument(shop));

      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(3));
    });

    testWidgets('selects with a tap, showing its delete button', (
      tester,
    ) async {
      final document = TestDocument(shop);
      await pumpDocument(tester, document);

      await tester.tap(find.byType(Divider), warnIfMissed: false);
      await tester.pumpAndSettle();
      final delete = find.byTooltip('Delete item').hitTestable();
      expect(delete, findsOneWidget);
      await tester.tap(delete);
      await tester.pumpAndSettle();

      expect(document.text, '- [ ] milk\n- [ ] eggs');
    });

    testWidgets('Backspace on it leaves the item empty, with the caret in '
        'it', (tester) async {
      final document = TestDocument(shop);
      await pumpDocument(tester, document);

      await tester.tap(find.byType(Divider), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.pressBackspace();
      await tester.typeImeText('bread');

      expect(document.text, '- [ ] milk\n- [ ] bread\n- [ ] eggs');
    });

    testWidgets("a soft keyboard's Backspace on it leaves the item empty", (
      tester,
    ) async {
      final document = TestDocument(shop);
      await pumpDocument(tester, document);

      await tester.tap(find.byType(Divider), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.softBackspace();

      expect(document.text, '- [ ] milk\n- [ ] \n- [ ] eggs');
    });

    testWidgets('selected by a tap, shows itself selected', (tester) async {
      await pumpDocument(tester, TestDocument(shop));

      await tester.tap(find.byType(Divider), warnIfMissed: false);
      await tester.pumpAndSettle();

      final shade = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byType(Divider),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (shade.decoration as BoxDecoration).color,
        isNot(Colors.transparent),
      );
    });

    testWidgets('selected, text typed goes into a new item after it', (
      tester,
    ) async {
      final document = TestDocument(shop);
      await pumpDocument(tester, document);

      await tester.tap(find.byType(Divider), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.typeImeText('x');

      expect(document.text, '- [ ] milk\n- [ ] ------\n- [ ] x\n- [ ] eggs');
    });

    for (final (keyboard, backspace) in _backspaces) {
      testWidgets('$keyboard: Backspace at the next item\'s start takes its '
          'box away, then removes the separator as one character', (
        tester,
      ) async {
        final document = TestDocument(shop);
        await pumpDocument(tester, document);

        await tester.caretIn(checkboxNodeOf(index: 1), 0);
        await backspace(tester);
        expect(document.text, '- [ ] milk\n- [ ] ------\n  eggs');
        await backspace(tester);
        await tester.typeImeText('x');

        expect(document.text, '- [ ] milk\n- [ ] xeggs');
      });
    }

    testWidgets('Delete at the end of the item above leaves the separator '
        'item empty, the caret staying', (tester) async {
      final document = TestDocument(shop);
      await pumpDocument(tester, document);

      await tester.caretIn(checkboxNodeOf(), 4);
      await tester.pressDelete();
      await tester.typeImeText('x');

      expect(document.text, '- [ ] milkx\n- [ ] \n- [ ] eggs');
    });

    testWidgets('lets the right arrow pass it', (tester) async {
      final document = TestDocument(shop);
      await pumpDocument(tester, document);

      await tester.caretIn(checkboxNodeOf(), 4);
      await tester.pressRightArrow();
      await tester.pressRightArrow();
      await tester.typeImeText('x');

      expect(document.text, '- [ ] milk\n- [ ] ------\n- [ ] exggs');
    });

    testWidgets('lets the left arrow pass it', (tester) async {
      final document = TestDocument(shop);
      await pumpDocument(tester, document);

      await tester.caretIn(checkboxNodeOf(index: 1), 0);
      await tester.pressLeftArrow();
      await tester.pressLeftArrow();
      await tester.typeImeText('x');

      expect(document.text, '- [ ] milxk\n- [ ] ------\n- [ ] eggs');
    });
  });

  for (final (keyboard, backspace) in _backspaces) {
    testWidgets('$keyboard: Backspace removes a tapped separator', (
      tester,
    ) async {
      final document = TestDocument('milk\n\n---\n\neggs');
      await pumpDocument(tester, document);

      await tester.tap(find.byType(Divider), warnIfMissed: false);
      await tester.pumpAndSettle();
      await backspace(tester);

      expect(document.text, 'milk\n\neggs');
    });

    testWidgets('$keyboard: Backspace right after a separator removes it, '
        'the caret staying', (tester) async {
      final document = TestDocument('milk\n\n---\n\neggs');
      await pumpDocument(tester, document);

      await tester.caretIn(paragraphNodeOf(index: 1), 0);
      await backspace(tester);
      await tester.typeImeText('x');

      expect(document.text, 'milk\n\nxeggs');
    });

    testWidgets('$keyboard: Backspace in an item\'s line below its '
        'separator removes the separator', (tester) async {
      final document = TestDocument('- [ ] milk\n- [ ] ------\n  eggs');
      await pumpDocument(tester, document);

      await tester.caretIn(paragraphNodeOf(), 0);
      await backspace(tester);

      expect(document.text, '- [ ] milk\n- [ ] eggs');
    });
  }

  testWidgets('the arrow keys pass a separator between paragraphs', (
    tester,
  ) async {
    final document = TestDocument('milk\n\n---\n\neggs');
    await pumpDocument(tester, document);

    await tester.caretIn(paragraphNodeOf(), 4);
    await tester.pressRightArrow();
    await tester.typeImeText('x');
    await tester.pressLeftArrow();
    await tester.pressLeftArrow();
    await tester.typeImeText('y');

    expect(document.text, 'milky\n\n---\n\nxeggs');
  });

  testWidgets('Separator adds a separator item after the caret\'s item', (
    tester,
  ) async {
    final document = TestDocument('- [ ] milk\n- [ ] eggs');
    await pumpDocument(tester, document);

    await tester.caretIn(checkboxNodeOf(), 2);
    await tester.tap(find.byTooltip('Separator'));
    await tester.pumpAndSettle();

    expect(document.text, '- [ ] milk\n- [ ] ***\n- [ ] eggs');
  });

  testWidgets('Separator on an empty item makes that item the separator', (
    tester,
  ) async {
    final document = TestDocument('- [ ] milk\n- [ ] \n- [ ] eggs');
    await pumpDocument(tester, document);

    await tester.caretIn(checkboxNodeOf(index: 1), 0);
    await tester.tap(find.byTooltip('Separator'));
    await tester.pumpAndSettle();
    await tester.typeImeText('x');

    expect(document.text, '- [ ] milk\n- [ ] ***\n- [ ] xeggs');
  });

  testWidgets('Separator with a separator selected adds one after it', (
    tester,
  ) async {
    final document = TestDocument('milk\n\n---\n\neggs');
    await pumpDocument(tester, document);

    await tester.tap(find.byType(Divider), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Separator'));
    await tester.pumpAndSettle();

    expect(document.text, 'milk\n\n---\n\n---\n\neggs');
  });

  testWidgets('a change from elsewhere shows right away', (tester) async {
    final document = TestDocument('- [ ] milk');
    await pumpDocument(tester, document);

    document.changeElsewhere('- [ ] milk\n- [ ] bread');
    await tester.pumpAndSettle();

    expect(
      SuperEditorInspector.findDocument()!.where(
        (node) => node is TextNode && markedItemOf(node) != null,
      ),
      hasLength(2),
    );
    expect(document.edits, isEmpty);
  });

  testWidgets('Bold wraps the selected word', (tester) async {
    final document = TestDocument('buy milk');
    await pumpDocument(tester, document);

    await tester.selectWordIn(paragraphNodeOf(), 5);
    await tester.tap(find.byTooltip('Bold (Ctrl+B)'));
    await tester.pumpAndSettle();

    expect(document.text, 'buy **milk**');
  });

  testWidgets('a paste is an undo step of its own', (tester) async {
    final document = TestDocument('a');
    await pumpDocument(tester, document);
    tester.clipboardHolds('bc');
    await tester.caretIn(paragraphNodeOf(), 1);
    await tester.typeImeText('x');

    await tester.pressCtlV();
    await tester.pumpAndSettle();
    await tester.typeImeText('y');
    document.undo();
    await tester.pumpAndSettle();
    expect(document.text, 'axbc');

    document.undo();
    await tester.pumpAndSettle();
    expect(document.text, 'ax');
  });

  testWidgets('a paste over a selected word is one undo step', (tester) async {
    final document = TestDocument('buy milk');
    await pumpDocument(tester, document);
    tester.clipboardHolds('eggs');
    await tester.selectWordIn(paragraphNodeOf(), 5);

    await tester.pressCtlV();
    await tester.pumpAndSettle();
    expect(document.text, 'buy eggs');

    document.undo();
    await tester.pumpAndSettle();
    expect(document.text, 'buy milk');
  });

  testWidgets('Bold leaves a code block as it is', (tester) async {
    final document = TestDocument('```\nbuy milk\n```');
    await pumpDocument(tester, document);

    await tester.selectWordIn(paragraphNodeOf(), 9);
    await tester.tap(find.byTooltip('Bold (Ctrl+B)'));
    await tester.pumpAndSettle();

    expect(document.text, '```\nbuy milk\n```');
  });

  testWidgets('Heading makes a heading inside a quote', (tester) async {
    final document = TestDocument('> quote');
    await pumpDocument(tester, document);

    await tester.caretIn(paragraphNodeOf(), 4);
    await tester.tap(find.byTooltip('Heading'));
    await tester.pumpAndSettle();

    expect(document.text, '> # quote');
  });

  group('a format keeps the caret where it puts it', () {
    Future<void> press(WidgetTester tester, String tooltip, int times) async {
      for (final _ in Iterable<void>.generate(times)) {
        await tester.tap(find.byTooltip(tooltip));
        await tester.pumpAndSettle();
      }
    }

    // The caret at the end of a row's text, then a few presses.
    for (final (start, row, caret, presses, typed) in [
      ('', 0, 0, 1, '# x\n'),
      ('', 0, 0, 2, '## x\n'),
      ('', 0, 0, 3, '### x\n'),
      ('Title', 0, 5, 1, '# Titlex'),
      ('Title', 0, 5, 2, '## Titlex'),
      ('Title', 0, 5, 4, 'Titlex'),
      ('a\n\nb', 1, 1, 1, 'a\n\n# bx'),
      ('a\n\nb', 1, 1, 2, 'a\n\n## bx'),
      ('a\n\nb\n\nc', 1, 1, 1, 'a\n\n# bx\n\nc'),
      ('a\n\nb\n\nc', 2, 1, 1, 'a\n\nb\n\n# cx'),
      ('Title\n===', 0, 5, 1, 'Titlex\n---'),
      ('Title\n---', 0, 5, 1, '### Titlex'),
    ]) {
      testWidgets('Heading $presses times at $caret of row $row in '
          '${jsonEncode(start)}, then typing', (tester) async {
        final document = TestDocument(start);
        await pumpDocument(tester, document);

        await tester.caretIn(paragraphNodeOf(index: row), caret);
        await press(tester, 'Heading', presses);
        await tester.typeImeText('x');

        expect(document.text, typed);
      });
    }

    testWidgets('Bold keeps the selected word selected', (tester) async {
      final document = TestDocument('a\n\nbuy milk');
      await pumpDocument(tester, document);

      await tester.selectWordIn(paragraphNodeOf(index: 1), 5);
      await press(tester, 'Bold (Ctrl+B)', 1);
      await tester.typeImeText('eggs');

      expect(document.text, 'a\n\nbuy **eggs**');
    });

    testWidgets('Bold with no selection types between its marks', (
      tester,
    ) async {
      final document = TestDocument('');
      await pumpDocument(tester, document);

      await tester.caretIn(paragraphNodeOf(), 0);
      await press(tester, 'Bold (Ctrl+B)', 1);
      await tester.typeImeText('milk');

      expect(document.text, '**milk**\n');
    });
  });

  group('Link', () {
    Future<void> addLink(WidgetTester tester, String url) async {
      await tester.enterText(find.byType(TextField), url);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
    }

    testWidgets('from the toolbar links the selected word', (tester) async {
      final document = TestDocument('buy milk');
      await pumpDocument(tester, document);

      await tester.selectWordIn(paragraphNodeOf(), 5);
      await tester.tap(find.byTooltip('Link (Ctrl+K)'));
      await tester.pumpAndSettle();
      await addLink(tester, 'https://x.org');

      expect(document.text, 'buy [milk](https://x.org)');
    });

    testWidgets('with Ctrl+K links the selected word', (tester) async {
      final document = TestDocument('buy milk');
      await pumpDocument(tester, document);

      await tester.selectWordIn(paragraphNodeOf(), 5);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await addLink(tester, 'https://x.org');

      expect(document.text, 'buy [milk](https://x.org)');
    });

    testWidgets('answered after Visual edit went (e.g. to Read) does '
        'nothing', (tester) async {
      final document = TestDocument('buy milk');
      await pumpDocument(tester, document);

      await tester.selectWordIn(paragraphNodeOf(), 5);
      await tester.tap(find.byTooltip('Link (Ctrl+K)'));
      await tester.pumpAndSettle();
      document.gate.send((_) => const SetMode(EditMode.read));
      await tester.pumpAndSettle();
      await addLink(tester, 'https://x.org');

      expect(tester.takeException(), isNull);
      expect(document.text, 'buy milk');
    });

    testWidgets('does nothing if the line changed meanwhile', (tester) async {
      // The paragraph keeps its first line, so it stays the same node.
      final document = TestDocument('buy milk\nand eggs');
      await pumpDocument(tester, document);

      await tester.selectWordIn(paragraphNodeOf(), 14);
      await tester.tap(find.byTooltip('Link (Ctrl+K)'));
      await tester.pumpAndSettle();
      document.changeElsewhere('buy milk\nand');
      await tester.pumpAndSettle();
      await addLink(tester, 'https://x.org');

      expect(document.text, 'buy milk\nand');
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelled leaves the line as it is', (tester) async {
      final document = TestDocument('buy milk');
      await pumpDocument(tester, document);

      await tester.selectWordIn(paragraphNodeOf(), 5);
      await tester.tap(find.byTooltip('Link (Ctrl+K)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(document.text, 'buy milk');
    });
  });

  group('list buttons', () {
    Future<void> press(WidgetTester tester, String button) async {
      await tester.tap(find.byTooltip(button));
      await tester.pumpAndSettle();
    }

    testWidgets('turn the caret line into an item, the caret kept', (
      tester,
    ) async {
      final document = TestDocument('milk\n\neggs');
      await pumpDocument(tester, document);

      await tester.caretIn(paragraphNodeOf(), 2);
      await press(tester, 'Checklist (Ctrl+Shift+9)');
      await tester.typeImeText('X');

      expect(document.text, '- [ ] miXlk\n\neggs');
    });

    testWidgets('put a box on an item, change its kind, and Checklist again '
        'makes it text', (tester) async {
      final document = TestDocument('- milk');
      await pumpDocument(tester, document);

      await tester.caretIn(listItemNodeOf(), 4);
      await press(tester, 'Checklist (Ctrl+Shift+9)');
      expect(document.text, '- [ ] milk');
      await press(tester, 'Numbered list (Ctrl+Shift+7)');
      expect(document.text, '1. [ ] milk');
      await press(tester, 'Checklist (Ctrl+Shift+9)');
      expect(document.text, 'milk');
      await tester.typeImeText('!');
      expect(document.text, 'milk!');
    });

    testWidgets('turn every selected line', (tester) async {
      final document = TestDocument('a\n\nb\n\nc');
      await pumpDocument(tester, document);

      await tester.caretIn(paragraphNodeOf(), 0);
      await tester.pressShiftDownArrow();
      await press(tester, 'Bulleted list (Ctrl+Shift+8)');

      expect(document.text, '- a\n- b\n\nc');
    });

    testWidgets('leave the items shown in the Done section as they are', (
      tester,
    ) async {
      final document = TestDocument('- [ ] a\n- [x] d\n- [ ] b');
      await pumpDocument(tester, document);

      await tester.caretIn(checkboxNodeOf(), 0);
      await tester.pressShiftDownArrow();
      await press(tester, 'Checklist (Ctrl+Shift+9)');

      expect(document.text, 'a\n\n- [x] d\n\nb');
    });

    testWidgets('tapped again over blank lines, turn the list back', (
      tester,
    ) async {
      final document = TestDocument('a\n\nb');
      await pumpDocument(tester, document);

      await tester.caretIn(paragraphNodeOf(), 0);
      await tester.pressShiftDownArrow();
      await tester.pressShiftDownArrow();
      await press(tester, 'Bulleted list (Ctrl+Shift+8)');
      expect(document.text, '- a\n- b');
      await press(tester, 'Bulleted list (Ctrl+Shift+8)');

      expect(document.text, 'a\n\nb');
    });

    testWidgets('in a new document, start a list for typing', (tester) async {
      final document = TestDocument('');
      await pumpDocument(tester, document);

      await press(tester, 'Checklist (Ctrl+Shift+9)');
      await tester.typeImeText('eggs');

      expect(document.text, '- [ ] eggs\n');
    });
  });

  testWidgets('Visual edit formats lines but not code', (tester) async {
    await pumpDocument(tester, TestDocument('```\n**a**\n```\n**b**\n* * *'));

    expect(find.textContaining('**a**', findRichText: true), findsOneWidget);
    expect(find.text('b', findRichText: true), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });

  group('links', () {
    const linkedText = 'see [docs](https://a.b) now\n\nother';

    testWidgets('a tap opens one in a line the caret is not in', (
      tester,
    ) async {
      final document = TestDocument(linkedText);
      await pumpDocument(tester, document);
      await tester.caretIn(paragraphNodeOf(index: 1), 0);

      await tester.tapAt(tester.tapPointIn(paragraphNodeOf(), 6));
      await tester.pumpAndSettle();

      expect(document.links, ['https://a.b']);
    });

    testWidgets('a tap in the caret line places the caret to edit it', (
      tester,
    ) async {
      final document = TestDocument(linkedText);
      await pumpDocument(tester, document);
      await tester.caretIn(paragraphNodeOf(), 0);

      await tester.caretIn(paragraphNodeOf(), 6);

      expect(document.links, isEmpty);
      expect(
        SuperEditorInspector.findDocumentSelection()!.extent.nodePosition,
        const TextNodePosition(offset: 6),
      );
    });

    for (final (name, text) in [
      ('a list item', '- see [docs](https://a.b) now\n\nother'),
      ('a quote', '> see [docs](https://a.b) now\n\nother'),
    ]) {
      testWidgets('a tap opens one in $name', (tester) async {
        final document = TestDocument(text);
        await pumpDocument(tester, document);
        final nodes = SuperEditorInspector.findDocument()!;
        await tester.caretIn(nodes.last.id, 0);

        final linked = nodes.firstWhere((node) => framesOf(node).isNotEmpty);
        await tester.tapAt(tester.tapPointIn(linked.id, 6));
        await tester.pumpAndSettle();

        expect(document.links, ['https://a.b']);
      });
    }
  });

  testWidgets('an empty document says Untitled until typed in', (tester) async {
    final document = TestDocument('');
    await pumpDocument(tester, document);
    expect(find.text('Untitled'), findsOneWidget);

    await tester.caretIn(paragraphNodeOf(), 0);
    await tester.typeImeText('Idea');

    expect(find.text('Untitled'), findsNothing);
    expect(document.text, 'Idea\n');
  });

  testWidgets('a tapped table shows its text with the caret in it, and is '
      'drawn again once the caret leaves', (tester) async {
    final document = TestDocument('| a |\n|---|\n\nafter');
    await pumpDocument(tester, document);

    await tester.tap(find.byType(DrawnTable));
    await tester.pumpAndSettle();
    expect(find.byType(DrawnTable), findsNothing);
    final caret = SuperEditorInspector.findDocumentSelection()!.extent;
    final node = SuperEditorInspector.findDocument()!.getNodeById(caret.nodeId);
    expect((node! as TextNode).text.toPlainText(), '| a |\n|---|');

    await tester.caretIn(paragraphNodeOf(index: 1), 0);
    expect(find.byType(DrawnTable), findsOneWidget);
  });

  group('a table that starts an item', () {
    const list = '- a\n- | x |\n  |---|\n- b';

    testWidgets('tapped, shows its text and the delete button', (tester) async {
      final document = TestDocument(list);
      await pumpDocument(tester, document);

      await tester.tap(find.byType(DrawnTable));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete item').hitTestable());
      await tester.pumpAndSettle();

      expect(document.text, '- a\n- b');
    });

    testWidgets('open as text, moves by its handle and is drawn again', (
      tester,
    ) async {
      final document = TestDocument(list);
      await pumpDocument(tester, document);

      await tester.tap(find.byType(DrawnTable));
      await tester.pumpAndSettle();
      final handles = find.byIcon(Icons.drag_indicator);
      final from = tester.getCenter(handles.at(1));
      final to = tester.getCenter(handles.at(2));
      final gesture = await tester.startGesture(
        from,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      for (final _ in Iterable<int>.generate(20)) {
        await gesture.moveBy((to - from + const Offset(0, 20)) / 20);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(document.text, '- a\n- b\n- | x |\n  |---|');
      expect(find.byType(DrawnTable), findsOneWidget);
    });
  });

  group('a table open as text in an item', () {
    const list = '- a\n- | x |\n  |---|\n- b';

    Future<void> openAndType(WidgetTester tester, TestDocument document) async {
      await pumpDocument(tester, document);
      await tester.tap(find.byType(DrawnTable));
      await tester.pumpAndSettle();
      await tester.typeImeText('y');
    }

    testWidgets('typed in, then shifted by its handle, closes and indents', (
      tester,
    ) async {
      final document = TestDocument(list);
      await openAndType(tester, document);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.drag_indicator).at(1)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      for (final _ in Iterable<int>.generate(20)) {
        await gesture.moveBy(const Offset(3, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // Typed at its start, the table reads as text now.
      expect(document.text, '- a\n  - y| x |\n    \\|---|\n- b');
    });

    testWidgets('closed by a toolbar button, shows itself selected', (
      tester,
    ) async {
      await pumpDocument(tester, TestDocument(list));
      await tester.tap(find.byType(DrawnTable));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Heading'));
      await tester.pumpAndSettle();

      final shade = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byType(DrawnTable),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (shade.decoration as BoxDecoration).color,
        isNot(Colors.transparent),
      );
    });

    testWidgets('typed in, the Separator button adds one after it', (
      tester,
    ) async {
      final document = TestDocument(list);
      await openAndType(tester, document);

      await tester.tap(find.byTooltip('Separator'));
      await tester.pumpAndSettle();

      expect(document.text, contains('y'));
      expect(document.text, endsWith('|---|\n- ***\n- b'));
    });
  });

  final linux = TargetPlatformVariant.only(TargetPlatform.linux);

  testWidgets('keypad keys move the caret with NumLock off', (tester) async {
    final document = TestDocument('buy milk');
    await pumpDocument(tester, document);

    await tester.caretIn(paragraphNodeOf(), 5);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad4);
    await tester.typeImeText('x');
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad7);
    await tester.typeImeText('y');

    expect(document.text, 'ybuy xmilk');
  }, variant: linux);

  testWidgets('keypad keys stay digits with NumLock on', (tester) async {
    final document = TestDocument('buy milk');
    await pumpDocument(tester, document);
    await tester.sendKeyEvent(LogicalKeyboardKey.numLock);
    addTearDown(() => tester.sendKeyEvent(LogicalKeyboardKey.numLock));

    await tester.caretIn(paragraphNodeOf(), 5);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad4);
    await tester.typeImeText('x');

    expect(document.text, 'buy mxilk');
  }, variant: linux);

  testWidgets('shows the images of the document', (tester) async {
    final image = MemoryImage(base64.decode(_onePixelPng));
    final document = TestDocument('# Doc\n\n![p](p.png)\n\nend');
    await pumpDocument(tester, document, images: _OneImage(image));

    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image == image,
      ),
      findsOne,
    );
  });
}

/// Every image a document refers to is [image].
final class _OneImage implements DocumentImages {
  const _OneImage(this.image);

  final ImageProvider image;

  @override
  ImageProvider? of(String url) => image;
}

/// A PNG picture of one pixel.
const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ'
    '/pLvAAAAAElFTkSuQmCC';

/// Backspace from a physical keyboard and from a soft keyboard.
final _backspaces = <(String, Future<void> Function(WidgetTester))>[
  (
    'keys',
    (tester) async {
      await tester.pressBackspace();
      await tester.pumpAndSettle();
    },
  ),
  ('soft keyboard', (tester) => tester.softBackspace()),
];
