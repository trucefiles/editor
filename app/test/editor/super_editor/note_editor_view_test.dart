import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_editor/editor/note_document_controller.dart';
import 'package:truce_editor/editor/note_mode.dart';
import 'package:truce_editor/editor/super_editor/components/drawn_table.dart';

import '../editor_support.dart';
import 'editor_robot.dart';

/// Editing a note in Visual edit, Markdown edit and Read.
void main() {
  final removed = <String>[];
  final links = <String>[];

  setUp(() {
    removed.clear();
    links.clear();
  });

  Future<NoteDocumentController> pumpEditor(
    WidgetTester tester,
    FakeNoteText text, {
    NoteMode mode = NoteMode.visual,
  }) => pumpNoteEditor(
    tester,
    text,
    mode: mode,
    onRemoved: (message, _) => removed.add(message),
    onLink: links.add,
  );

  testWidgets('typing in an item changes only its line', (tester) async {
    final text = FakeNoteText('# Shop\n- [ ] milk\n- [ ] eggs');
    await pumpEditor(tester, text);

    await tester.caretIn(checkboxNodeOf(), 4);
    await tester.typeImeText(' oat');

    expect(text.text, '# Shop\n- [ ] milk oat\n- [ ] eggs');
  });

  testWidgets('Enter at the end of an item starts the next one', (
    tester,
  ) async {
    final text = FakeNoteText('- [ ] milk\n1. one');
    await pumpEditor(tester, text);

    await tester.caretIn(checkboxNodeOf(), 4);
    await tester.pressEnter();
    await tester.typeImeText('eggs');
    await tester.caretIn(listItemNodeOf(), 3);
    await tester.pressEnter();
    await tester.typeImeText('two');

    expect(text.text, '- [ ] milk\n- [ ] eggs\n1. one\n2. two');
  });

  testWidgets('Backspace at the start joins the item to the one above', (
    tester,
  ) async {
    final text = FakeNoteText('- [ ] milk\n- [ ] eggs');
    await pumpEditor(tester, text);

    await tester.caretIn(checkboxNodeOf(index: 1), 0);
    await tester.pressBackspace();

    expect(text.text, '- [ ] milkeggs');
  });

  testWidgets('tapping the box checks the item', (tester) async {
    final text = FakeNoteText('- [ ] milk\n- [ ] eggs');
    await pumpEditor(tester, text);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(text.text, '- [x] milk\n- [ ] eggs');
    expect(find.text('Done (1)'), findsOneWidget);
  });

  testWidgets('the Done heading folds its items away', (tester) async {
    final text = FakeNoteText('- [ ] milk\n- [x] eggs');
    await pumpEditor(tester, text);
    expect(find.byType(Checkbox), findsNWidgets(2));

    await tester.tap(find.text('Done (1)'));
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsOneWidget);
    expect(text.edits, isEmpty);
  });

  testWidgets('Add item adds an item of the list\'s kind for typing', (
    tester,
  ) async {
    final text = FakeNoteText('- [ ] milk');
    await pumpEditor(tester, text);

    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.typeImeText('eggs');

    expect(text.text, '- [ ] eggs\n- [ ] milk');
  });

  testWidgets('deleting an item from its menu offers undo', (tester) async {
    final text = FakeNoteText('- [ ] milk\n- [ ] eggs');
    await pumpEditor(tester, text);

    await tester.caretIn(checkboxNodeOf(), 0);
    final menu = find.byTooltip('Item actions').hitTestable();
    expect(menu, findsOneWidget, reason: 'only the edited row has a menu');
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(text.text, '- [ ] eggs');
    expect(removed, ['Item deleted']);
  });

  testWidgets('a change from elsewhere shows right away', (tester) async {
    final text = FakeNoteText('- [ ] milk');
    await pumpEditor(tester, text);

    text.changeElsewhere('- [ ] milk\n- [ ] bread');
    await tester.pumpAndSettle();

    expect(
      SuperEditorInspector.findDocument()!.where(
        (node) => markedItemOf(node) != null,
      ),
      hasLength(2),
    );
    expect(text.edits, isEmpty);
  });

  testWidgets('Bold wraps the selected word', (tester) async {
    final text = FakeNoteText('buy milk');
    await pumpEditor(tester, text);

    await tester.selectWordIn(paragraphNodeOf(), 5);
    await tester.tap(find.byTooltip('Bold (Ctrl+B)'));
    await tester.pumpAndSettle();

    expect(text.text, 'buy **milk**');
  });

  testWidgets('Bold leaves a code block as it is', (tester) async {
    final text = FakeNoteText('```\nbuy milk\n```');
    await pumpEditor(tester, text);

    await tester.selectWordIn(paragraphNodeOf(), 9);
    await tester.tap(find.byTooltip('Bold (Ctrl+B)'));
    await tester.pumpAndSettle();

    expect(text.text, '```\nbuy milk\n```');
  });

  testWidgets('Heading leaves a quote as it is', (tester) async {
    final text = FakeNoteText('> quote');
    await pumpEditor(tester, text);

    await tester.caretIn(paragraphNodeOf(), 4);
    await tester.tap(find.byTooltip('Heading'));
    await tester.pumpAndSettle();

    expect(text.text, '> quote');
  });

  group('Link', () {
    Future<void> addLink(WidgetTester tester, String url) async {
      await tester.enterText(find.byType(TextField), url);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
    }

    testWidgets('from the toolbar links the selected word', (tester) async {
      final text = FakeNoteText('buy milk');
      await pumpEditor(tester, text);

      await tester.selectWordIn(paragraphNodeOf(), 5);
      await tester.tap(find.byTooltip('Link (Ctrl+K)'));
      await tester.pumpAndSettle();
      await addLink(tester, 'https://x.org');

      expect(text.text, 'buy [milk](https://x.org)');
    });

    testWidgets('with Ctrl+K links the selected word', (tester) async {
      final text = FakeNoteText('buy milk');
      await pumpEditor(tester, text);

      await tester.selectWordIn(paragraphNodeOf(), 5);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await addLink(tester, 'https://x.org');

      expect(text.text, 'buy [milk](https://x.org)');
    });

    testWidgets('does nothing if the line changed meanwhile', (tester) async {
      // The paragraph keeps its first line, so it stays the same node.
      final text = FakeNoteText('buy milk\nand eggs');
      await pumpEditor(tester, text);

      await tester.selectWordIn(paragraphNodeOf(), 14);
      await tester.tap(find.byTooltip('Link (Ctrl+K)'));
      await tester.pumpAndSettle();
      text.changeElsewhere('buy milk\nand');
      await tester.pumpAndSettle();
      await addLink(tester, 'https://x.org');

      expect(text.text, 'buy milk\nand');
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelled leaves the line as it is', (tester) async {
      final text = FakeNoteText('buy milk');
      await pumpEditor(tester, text);

      await tester.selectWordIn(paragraphNodeOf(), 5);
      await tester.tap(find.byTooltip('Link (Ctrl+K)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(text.text, 'buy milk');
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
      final text = FakeNoteText('milk\neggs');
      await pumpEditor(tester, text);

      await tester.caretIn(paragraphNodeOf(), 2);
      await press(tester, 'Checklist');
      await tester.typeImeText('X');

      expect(text.text, '- [ ] miXlk\neggs');
    });

    testWidgets('change the kind of an item and back to text', (tester) async {
      final text = FakeNoteText('- [ ] milk');
      await pumpEditor(tester, text);

      await tester.caretIn(checkboxNodeOf(), 4);
      await press(tester, 'Numbered list');
      expect(text.text, '1. milk');
      await press(tester, 'Numbered list');
      expect(text.text, 'milk');
      await tester.typeImeText('!');
      expect(text.text, 'milk!');
    });

    testWidgets('turn every selected line', (tester) async {
      final text = FakeNoteText('a\nb\nc');
      await pumpEditor(tester, text);

      await tester.caretIn(paragraphNodeOf(), 0);
      await tester.pressShiftDownArrow();
      await press(tester, 'Bulleted list');

      expect(text.text, '- a\n- b\nc');
    });

    testWidgets('leave the items shown in the Done section as they are', (
      tester,
    ) async {
      final text = FakeNoteText('- [ ] a\n- [x] d\n- [ ] b');
      await pumpEditor(tester, text);

      await tester.caretIn(checkboxNodeOf(), 0);
      await tester.pressShiftDownArrow();
      await press(tester, 'Checklist');

      expect(text.text, 'a\n- [x] d\nb');
    });

    testWidgets('tapped again over blank lines, turn the list back', (
      tester,
    ) async {
      final text = FakeNoteText('a\n\nb');
      await pumpEditor(tester, text);

      await tester.caretIn(paragraphNodeOf(), 0);
      await tester.pressShiftDownArrow();
      await tester.pressShiftDownArrow();
      await press(tester, 'Bulleted list');
      expect(text.text, '- a\n\n- b');
      await press(tester, 'Bulleted list');

      expect(text.text, 'a\n\nb');
    });

    testWidgets('without a caret, add an item at the end for typing', (
      tester,
    ) async {
      final text = FakeNoteText('milk\n');
      await pumpEditor(tester, text);

      await press(tester, 'Checklist');
      await tester.typeImeText('eggs');

      expect(text.text, 'milk\n- [ ] eggs\n');
    });
  });

  testWidgets('Markdown edit edits every character', (tester) async {
    final text = FakeNoteText('- [ ] milk');
    await pumpEditor(tester, text, mode: NoteMode.markdown);
    expect(find.byType(Checkbox), findsNothing);

    await tester.caretIn(paragraphNodeOf(), 4);
    await tester.typeImeText('x');

    expect(text.text, '- [ x] milk');
  });

  testWidgets('Visual edit formats lines but not code', (tester) async {
    await pumpEditor(tester, FakeNoteText('```\n**a**\n```\n**b**\n* * *'));

    expect(find.textContaining('**a**', findRichText: true), findsOneWidget);
    expect(find.text('b', findRichText: true), findsOneWidget);
    expect(find.text('* * *', findRichText: true), findsOneWidget);
  });

  group('links', () {
    const note = 'see [docs](https://a.b) now\n\nother';

    testWidgets('a tap opens one in a line the caret is not in', (
      tester,
    ) async {
      await pumpEditor(tester, FakeNoteText(note));
      await tester.caretIn(paragraphNodeOf(index: 2), 0);

      await tester.tapAt(tester.tapPointIn(paragraphNodeOf(), 6));
      await tester.pumpAndSettle();

      expect(links, ['https://a.b']);
    });

    testWidgets('a tap in the caret line places the caret to edit it', (
      tester,
    ) async {
      await pumpEditor(tester, FakeNoteText(note));
      await tester.caretIn(paragraphNodeOf(), 0);

      await tester.caretIn(paragraphNodeOf(), 6);

      expect(links, isEmpty);
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
        await pumpEditor(tester, FakeNoteText(text));
        final document = SuperEditorInspector.findDocument()!;
        await tester.caretIn(document.last.id, 0);

        final linked = document.firstWhere((node) => framesIn(node).isNotEmpty);
        await tester.tapAt(tester.tapPointIn(linked.id, 6));
        await tester.pumpAndSettle();

        expect(links, ['https://a.b']);
      });
    }

    testWidgets('in Markdown edit, only Ctrl and a tap open one', (
      tester,
    ) async {
      await pumpEditor(tester, FakeNoteText(note), mode: NoteMode.markdown);
      final link = tester.tapPointIn(paragraphNodeOf(), 6);

      await tester.tapAt(link);
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();
      expect(links, isEmpty);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tapAt(link);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(links, ['https://a.b']);
    });
  });

  testWidgets('an empty note says Untitled until typed in', (tester) async {
    final text = FakeNoteText('');
    await pumpEditor(tester, text);
    expect(find.text('Untitled'), findsOneWidget);

    await tester.caretIn(paragraphNodeOf(), 0);
    await tester.typeImeText('Idea');

    expect(find.text('Untitled'), findsNothing);
    expect(text.text, 'Idea');
  });

  testWidgets('a tapped table shows its text with the caret in it, and is '
      'drawn again once the caret leaves', (tester) async {
    final text = FakeNoteText('| a |\n|---|\n\nafter');
    await pumpEditor(tester, text);

    await tester.tap(find.byType(DrawnTable));
    await tester.pumpAndSettle();
    expect(find.byType(DrawnTable), findsNothing);
    final caret = SuperEditorInspector.findDocumentSelection()!.extent;
    final node = SuperEditorInspector.findDocument()!.getNodeById(caret.nodeId);
    expect((node! as TextNode).text.toPlainText(), '| a |\n|---|');

    await tester.caretIn(paragraphNodeOf(index: 2), 0);
    expect(find.byType(DrawnTable), findsOneWidget);
  });

  testWidgets('pasted Windows line breaks make lines', (tester) async {
    final text = FakeNoteText('');
    await pumpEditor(tester, text, mode: NoteMode.markdown);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, Object?>{'text': 'a\r\nb\rc'}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.caretIn(paragraphNodeOf(), 0);
    await tester.pressCtlV();
    await tester.pumpAndSettle();

    expect(text.text, 'a\nb\nc');
  });

  final linux = TargetPlatformVariant.only(TargetPlatform.linux);

  testWidgets('keypad keys move the caret with NumLock off', (tester) async {
    final text = FakeNoteText('buy milk');
    await pumpEditor(tester, text);

    await tester.caretIn(paragraphNodeOf(), 5);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad4);
    await tester.typeImeText('x');
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad7);
    await tester.typeImeText('y');

    expect(text.text, 'ybuy xmilk');
  }, variant: linux);

  testWidgets('keypad keys stay digits with NumLock on', (tester) async {
    final text = FakeNoteText('buy milk');
    await pumpEditor(tester, text);
    await tester.sendKeyEvent(LogicalKeyboardKey.numLock);
    addTearDown(() => tester.sendKeyEvent(LogicalKeyboardKey.numLock));

    await tester.caretIn(paragraphNodeOf(), 5);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad4);
    await tester.typeImeText('x');

    expect(text.text, 'buy mxilk');
  }, variant: linux);
}
