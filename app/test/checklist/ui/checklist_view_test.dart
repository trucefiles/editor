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
  Future<ChecklistEditor> show(WidgetTester tester, String text) async {
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
      saveDelay: const Duration(days: 1),
    );
    final editor = ChecklistEditor(session);
    addTearDown(editor.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: Scaffold(body: ChecklistView(editor))),
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
    await tester.enterText(find.byType(TextField).at(1), 'x');
    await tester.tap(field('b'));
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
