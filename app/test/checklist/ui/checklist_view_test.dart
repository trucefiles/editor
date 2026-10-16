import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/checklist/checklist_editor.dart';
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
}
