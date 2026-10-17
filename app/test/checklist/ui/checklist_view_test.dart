import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/checklist/checklist_editor.dart';
import 'package:truce_editor/checklist/ui/checklist_row.dart';
import 'package:truce_editor/checklist/ui/checklist_view.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_edit_session.dart';
import 'package:truce_editor/notes/note_files.dart';

import '../../support.dart';

void main() {
  late NoteEditSession session;

  /// Shows [text] as a checklist. Nothing is saved during the test; call
  /// [close] at its end.
  Future<ChecklistEditor> show(
    WidgetTester tester,
    String text, {
    bool separateDone = true,
  }) async {
    final dir = tempFolder();
    final folder = folderAt(dir);
    final note = Note(
      folder: folder,
      path: path('a.md'),
      file: const TextFile.empty().withText(text),
      version: const FileVersion(0),
      modified: DateTime(2000),
    );
    session = NoteEditSession(
      note,
      NoteFiles(folder, servicesFor(folder)),
      tempDrafts(),
      saveDelay: const Duration(days: 1),
    );
    final editor = ChecklistEditor(session);
    addTearDown(editor.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ChecklistView(editor, separateDone: separateDone),
          ),
        ),
      ),
    );
    return editor;
  }

  /// Drops the session and its pending save before the test ends.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  }

  /// The text field showing [text].
  Finder field(String text) => find.widgetWithText(TextField, text);

  bool hasFocus(WidgetTester tester, String text) =>
      tester.widget<TextField>(field(text)).focusNode!.hasFocus;

  testWidgets('arrow keys move the cursor between items', (tester) async {
    await show(tester, '- [ ] a\n- [ ] b\n- [x] c');
    await tester.tap(field('a'));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(hasFocus(tester, 'b'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(hasFocus(tester, 'c'), isTrue, reason: 'past the add row');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(
      tester.widget<TextField>(field('Add item')).focusNode!.hasFocus,
      isTrue,
    );
  });

  testWidgets('typing in the add row starts an item in the note', (
    tester,
  ) async {
    final editor = await show(tester, '');

    await tester.enterText(field('Add item'), 'M');
    await tester.pump();

    expect(editor.list.text, '- [ ] M\n');
    expect(session.text, '- [ ] M\n', reason: 'saved without Enter');
    expect(hasFocus(tester, 'M'), isTrue, reason: 'typing goes on there');
    expect(
      tester.widget<TextField>(field('M')).controller!.selection,
      const TextSelection.collapsed(offset: 1),
    );
    expect(tester.widget<TextField>(field('Add item')).controller!.text, '');

    await tester.enterText(field('M'), 'Milk');
    await tester.pump();
    expect(session.text, '- [ ] Milk\n');
    await close(tester);
  });

  testWidgets('typing in the top add row starts an item above the others', (
    tester,
  ) async {
    final editor = await show(tester, '# Todo\n- [ ] a\n- [ ] b\n');

    await tester.enterText(field('Add item at top'), 'M');
    await tester.pump();

    expect(editor.list.text, '# Todo\n- [ ] M\n- [ ] a\n- [ ] b\n');
    expect(hasFocus(tester, 'M'), isTrue, reason: 'typing goes on there');
    expect(
      tester.widget<TextField>(field('Add item at top')).controller!.text,
      '',
    );
    await close(tester);
  });

  group('typing fast in an add row keeps every key', () {
    for (final (hint, before, after) in [
      ('Add item at top', '- [ ] M', '\n- [ ] a\n'),
      ('Add item', '- [ ] a\n- [ ] M', '\n'),
    ]) {
      testWidgets(hint, (tester) async {
        final editor = await show(tester, '- [ ] a\n');

        // Both keys arrive before the new item's row takes the cursor.
        await tester.enterText(field(hint), 'M');
        tester.testTextInput.enterText('Mi');
        await tester.pump();
        await tester.pump();

        expect(editor.list.text, '${before}i$after');
        expect(hasFocus(tester, 'Mi'), isTrue, reason: 'typing goes on there');
        expect(tester.widget<TextField>(field(hint)).controller!.text, '');
        await close(tester);
      });
    }
  });

  testWidgets('Enter moves to the new item without closing the keyboard', (
    tester,
  ) async {
    final editor = await show(tester, '- [ ] a\n- [ ] b');
    await tester.tap(field('a'));
    await tester.pump();
    tester.testTextInput.log.clear();

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();

    expect(editor.list.text, '- [ ] a\n- [ ] \n- [ ] b');
    // The fields: top add row, a, the new item, b, add row.
    final added = tester.widget<TextField>(find.byType(TextField).at(2));
    expect(added.focusNode!.hasFocus, isTrue);
    expect(
      tester.testTextInput.log.map((call) => call.method),
      isNot(contains('TextInput.hide')),
    );
    await close(tester);
  });

  testWidgets('without open items there is one add row', (tester) async {
    await show(tester, '- [x] a');

    expect(field('Add item at top'), findsNothing);
    expect(field('Add item'), findsOneWidget);
    await close(tester);
  });

  testWidgets('spaces alone in the add row start no item', (tester) async {
    final editor = await show(tester, '- [ ] a');

    await tester.enterText(field('Add item'), ' ');
    await tester.pump();
    expect(editor.list.text, '- [ ] a');

    await tester.enterText(field('Add item'), ' b');
    await tester.pump();
    expect(editor.list.text, '- [ ] a\n- [ ] b');
    await close(tester);
  });

  testWidgets('the done count counts only checked items', (tester) async {
    await show(tester, '- [x] a\n  - [ ] sub\n- [ ] b');

    expect(find.text('1 done'), findsOneWidget);
    await close(tester);
  });

  testWidgets('without a Done section, checked items stay in place', (
    tester,
  ) async {
    final editor = await show(
      tester,
      '- [ ] a\n- [x] done\n- [ ] b',
      separateDone: false,
    );
    await tester.tap(field('b'));
    await tester.pump();

    expect(find.text('1 done'), findsNothing);
    // The checked item is shown above, so b goes under it.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(editor.list.text, '- [ ] a\n- [x] done\n  - [ ] b');
    await close(tester);
  });

  testWidgets('tab indents under the open item shown above', (tester) async {
    final editor = await show(tester, '- [ ] a\n- [x] done\n- [ ] b');
    await tester.tap(field('b'));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(editor.list.text, '- [ ] a\n  - [ ] b\n- [x] done');
    expect(find.text('1 done'), findsOneWidget);
    await close(tester);
  });

  testWidgets('tab in the done section indents under the done item above', (
    tester,
  ) async {
    final editor = await show(tester, '- [ ] a\n- [x] d1\n- [x] d2');
    await tester.tap(field('d2'));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(editor.list.text, '- [ ] a\n- [x] d1\n  - [x] d2');
    await close(tester);
  });

  testWidgets('swiping right indents, left outdents', (tester) async {
    final editor = await show(tester, '- [ ] a\n- [ ] b');

    await tester.drag(field('b'), const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(editor.list.text, '- [ ] a\n  - [ ] b');

    await tester.drag(field('b'), const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(editor.list.text, '- [ ] a\n- [ ] b');
    await close(tester);
  });

  testWidgets('a mouse drag indents from the checkbox, not the text', (
    tester,
  ) async {
    final editor = await show(tester, '- [ ] a\n- [ ] b');

    await tester.drag(
      field('b'),
      const Offset(100, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(editor.list.text, '- [ ] a\n- [ ] b', reason: 'selects text');

    await tester.drag(
      find.byType(Checkbox).at(1),
      const Offset(100, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(editor.list.text, '- [ ] a\n  - [ ] b');
    await close(tester);
  });

  testWidgets('a mouse drag by one level outdents', (tester) async {
    final editor = await show(tester, '- [ ] a\n  - [ ] b');
    final a = tester.getCenter(find.byType(Checkbox).at(0));
    final b = tester.getCenter(find.byType(Checkbox).at(1));

    // Left by the width of one level, as shown on screen.
    await tester.dragFrom(
      b,
      Offset(a.dx - b.dx, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(editor.list.text, '- [ ] a\n- [ ] b');
    await close(tester);
  });

  testWidgets('shows the lines between items as Markdown', (tester) async {
    await show(tester, '# Shop\n\n**Fresh** only\n- [ ] milk');

    expect(find.text('Shop'), findsOne);
    expect(find.textContaining('#'), findsNothing);
    expect(find.textContaining('**'), findsNothing);
    expect(field('milk'), findsOne);
    await close(tester);
  });

  testWidgets('dragging an item takes its indented text along', (tester) async {
    final editor = await show(tester, '- [ ] a\n- [ ] b\n  note');

    final handle = find.byIcon(Icons.drag_indicator).at(1);
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(kLongPressTimeout);
    await gesture.moveBy(const Offset(0, -200));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(editor.list.text, '- [ ] b\n  note\n- [ ] a');
    expect(find.text('note'), findsOne);
    await close(tester);
  });

  testWidgets('a long press that moves, to select text, does not indent', (
    tester,
  ) async {
    final editor = await show(tester, '- [ ] a\n- [ ] b');

    final gesture = await tester.startGesture(tester.getCenter(field('b')));
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

    expect(editor.list.text, '- [ ] a\n- [ ] b');
    await close(tester);
  });

  testWidgets('a long item wraps, and a swipe on its text indents it', (
    tester,
  ) async {
    final long = 'long ' * 100;
    final editor = await show(tester, '- [ ] a\n- [ ] $long');

    await tester.drag(field(long), const Offset(100, 0));
    await tester.pumpAndSettle();

    expect(editor.list.text, '- [ ] a\n  - [ ] $long');
    await close(tester);
  });

  testWidgets('only the row being edited shows its menu', (tester) async {
    await show(tester, '- [ ] a\n- [ ] b');
    final menus = find.byTooltip('Item actions').hitTestable();
    expect(menus, findsNothing);

    await tester.tap(field('b'));
    await tester.pump();

    expect(menus, findsOneWidget);
    await tester.tap(menus);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(field('b'), findsNothing);
    await close(tester);
  });

  testWidgets('a short swipe does nothing', (tester) async {
    final editor = await show(tester, '- [ ] a\n- [ ] b');

    await tester.drag(field('b'), const Offset(20, 0));
    await tester.pumpAndSettle();

    expect(editor.list.text, '- [ ] a\n- [ ] b');
    await close(tester);
  });

  testWidgets('undo after a delete shows each line in its row', (tester) async {
    final editor = await show(tester, '- [ ] a\n- [ ] b');
    await tester.tap(field('a'));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    // The fields: top add row, a, the new item, b, add row.
    await tester.enterText(find.byType(TextField).at(2), 'x');
    await tester.tap(field('x'));
    await tester.pump();

    await tester.tap(find.byTooltip('Item actions').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    final shown = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller!.text)
        .where((text) => text.isNotEmpty);
    expect(shown, ['a', 'x', 'b']);
    expect(editor.list.text, '- [ ] a\n- [ ] x\n- [ ] b');
    await close(tester);
  });

  testWidgets('the undo hint goes away on its own', (tester) async {
    await show(tester, '- [ ] a\n- [x] b');

    await tester.tap(find.text('Clear done'));
    await tester.pump();
    expect(find.text('Done items cleared'), findsOneWidget);

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Done items cleared'), findsNothing);
    await close(tester);
  });

  group('add rows', () {
    double top(WidgetTester tester, Finder finder) =>
        tester.getTopLeft(finder).dy;

    testWidgets('sit right above the first item and below the last', (
      tester,
    ) async {
      await show(tester, '# Shop\nintro\n- [ ] a\n## Later\n- [ ] b\n\nnote');

      final order = [
        find.text('Shop'),
        field('Add item at top'),
        field('a'),
        find.text('Later'),
        field('b'),
        field('Add item'),
        find.text('note'),
      ].map((finder) => top(tester, finder)).toList();
      expect(order, [...order]..sort());
      await close(tester);
    });

    testWidgets('add where they sit', (tester) async {
      final editor = await show(tester, '# Shop\n- [ ] a\n  - [ ] sub\n\nnote');

      await tester.enterText(field('Add item at top'), 'T');
      await tester.pump();
      await tester.enterText(field('Add item'), 'B');
      await tester.pump();

      expect(
        editor.list.text,
        '# Shop\n- [ ] T\n- [ ] a\n  - [ ] sub\n- [ ] B\n\nnote',
      );
      await close(tester);
    });

    testWidgets('keep indented text below the last item above them', (
      tester,
    ) async {
      await show(tester, '- [ ] a\n  details');

      expect(
        top(tester, find.text('details')),
        lessThan(top(tester, field('Add item'))),
      );
      await close(tester);
    });

    testWidgets('go by the open items, past done ones and their text', (
      tester,
    ) async {
      final editor = await show(tester, '- [x] d\n# Open\n- [ ] a\n- [x] e');

      await tester.enterText(field('Add item at top'), 'T');
      await tester.pump();
      await tester.enterText(field('Add item'), 'B');
      await tester.pump();

      expect(
        editor.list.text,
        '- [x] d\n# Open\n- [ ] T\n- [ ] a\n- [ ] B\n- [x] e',
      );
      await close(tester);
    });

    testWidgets('line up with the items', (tester) async {
      await show(tester, '- [ ] a');

      expect(
        tester.getCenter(find.byIcon(Icons.add).first).dx,
        tester.getCenter(find.byType(Checkbox)).dx,
      );
      expect(
        tester.getTopLeft(field('Add item')).dx,
        tester.getTopLeft(field('a')).dx,
      );
      await close(tester);
    });

    testWidgets('dragging an item to the end keeps it above the text below', (
      tester,
    ) async {
      final editor = await show(tester, '- [ ] a\n- [ ] b\n\nnote');

      final handle = find.byIcon(Icons.drag_indicator).first;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(kLongPressTimeout);
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(editor.list.text, '- [ ] b\n- [ ] a\n\nnote');
      await close(tester);
    });
  });

  group('joining items', () {
    /// Puts the cursor of [field] at [offset].
    Future<void> cursorIn(WidgetTester tester, Finder field, int offset) async {
      await tester.tap(field);
      await tester.pump();
      tester.widget<TextField>(field).controller!.selection =
          TextSelection.collapsed(offset: offset);
      await tester.pump();
    }

    /// Puts the cursor of the field showing [text] at [offset].
    Future<void> cursorAt(WidgetTester tester, String text, int offset) =>
        cursorIn(tester, field(text), offset);

    /// Text field of the [index]th item row.
    Finder item(int index) => find.descendant(
      of: find.byType(ChecklistItemRow).at(index),
      matching: find.byType(TextField),
    );

    TextSelection selectionOf(WidgetTester tester, String text) =>
        tester.widget<TextField>(field(text)).controller!.selection;

    testWidgets('Backspace at the start joins the item to the one above', (
      tester,
    ) async {
      final editor = await show(tester, '- [ ] milk\n- [ ] eggs');
      await cursorAt(tester, 'eggs', 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(editor.list.text, '- [ ] milkeggs');
      expect(hasFocus(tester, 'milkeggs'), isTrue);
      expect(
        selectionOf(tester, 'milkeggs'),
        const TextSelection.collapsed(offset: 4),
      );
      await close(tester);
    });

    testWidgets('Delete at the end joins the item below onto it', (
      tester,
    ) async {
      final editor = await show(tester, '- [ ] milk\n- [ ] eggs');
      await cursorAt(tester, 'milk', 4);

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      expect(editor.list.text, '- [ ] milkeggs');
      expect(hasFocus(tester, 'milkeggs'), isTrue);
      expect(
        selectionOf(tester, 'milkeggs'),
        const TextSelection.collapsed(offset: 4),
      );
      await close(tester);
    });

    testWidgets('either key drops an empty item', (tester) async {
      final editor = await show(
        tester,
        '- [ ] a\n- [ ] \n- [ ] \n- [x] b',
        separateDone: false,
      );
      await cursorIn(tester, item(1), 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(editor.list.text, '- [ ] a\n- [ ] \n- [x] b');
      expect(
        selectionOf(tester, 'a'),
        const TextSelection.collapsed(offset: 1),
      );

      await cursorIn(tester, item(1), 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(editor.list.text, '- [ ] a\n- [x] b', reason: 'b keeps its box');
      expect(hasFocus(tester, 'b'), isTrue);
      expect(
        selectionOf(tester, 'b'),
        const TextSelection.collapsed(offset: 0),
      );
      await close(tester);
    });

    testWidgets('either key drops an empty item with nothing to join', (
      tester,
    ) async {
      final editor = await show(tester, '# T\n- [ ] \n- [ ] a\n- [ ] ');

      await cursorIn(tester, item(0), 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(editor.list.text, '# T\n- [ ] a\n- [ ] ', reason: 'below text');
      expect(hasFocus(tester, 'a'), isTrue, reason: 'not the top add row');

      await cursorIn(tester, item(1), 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(editor.list.text, '# T\n- [ ] a', reason: 'the last item');
      expect(
        tester.widget<TextField>(field('Add item')).focusNode!.hasFocus,
        isTrue,
      );
      await close(tester);
    });

    testWidgets('drops the only item if it is empty', (tester) async {
      final editor = await show(tester, '- [ ] ');

      await cursorIn(tester, item(0), 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(editor.list.text, '');
      await close(tester);
    });

    testWidgets('keys inside the text edit it as usual', (tester) async {
      final editor = await show(tester, '- [ ] milk\n- [ ] eggs');
      await cursorAt(tester, 'eggs', 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(editor.list.text, '- [ ] milk\n- [ ] egs');
      await close(tester);
    });

    testWidgets('nothing joins across text or past the first item', (
      tester,
    ) async {
      final editor = await show(tester, '- [ ] a\n# Later\n- [ ] b');

      await cursorAt(tester, 'b', 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await cursorAt(tester, 'a', 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(editor.list.text, '- [ ] a\n# Later\n- [ ] b');
      await close(tester);
    });
  });
}
