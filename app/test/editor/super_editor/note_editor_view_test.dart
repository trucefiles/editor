import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_editor/editor/note_document_controller.dart';
import 'package:truce_editor/editor/super_editor/note_editor_view.dart';
import 'package:truce_editor/notes/note_mode.dart';

import '../editor_support.dart';

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
  }) async {
    final note = documentOf(text, mode: mode);
    addTearDown(note.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditorView(
            note,
            onRemoved: (message, _) => removed.add(message),
            onLink: links.add,
          ),
        ),
      ),
    );
    return note;
  }

  String nodeOf<T extends DocumentNode>({int index = 0}) =>
      SuperEditorInspector.findDocument()!.whereType<T>().elementAt(index).id;

  Future<void> caretAt(WidgetTester tester, String nodeId, int offset) =>
      tester.placeCaretInComponent(nodeId, TextNodePosition(offset: offset));

  testWidgets('typing in an item changes only its line', (tester) async {
    final text = FakeNoteText('# Shop\n- [ ] milk\n- [ ] eggs');
    await pumpEditor(tester, text);

    await caretAt(tester, nodeOf<TaskNode>(), 4);
    await tester.typeImeText(' oat');

    expect(text.text, '# Shop\n- [ ] milk oat\n- [ ] eggs');
  });

  testWidgets('Enter at the end of an item starts the next one', (
    tester,
  ) async {
    final text = FakeNoteText('- [ ] milk\n1. one');
    await pumpEditor(tester, text);

    await caretAt(tester, nodeOf<TaskNode>(), 4);
    await tester.pressEnter();
    await tester.typeImeText('eggs');
    await caretAt(tester, nodeOf<ListItemNode>(), 3);
    await tester.pressEnter();
    await tester.typeImeText('two');

    expect(text.text, '- [ ] milk\n- [ ] eggs\n1. one\n2. two');
  });

  testWidgets('Backspace at the start joins the item to the one above', (
    tester,
  ) async {
    final text = FakeNoteText('- [ ] milk\n- [ ] eggs');
    await pumpEditor(tester, text);

    await caretAt(tester, nodeOf<TaskNode>(index: 1), 0);
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

  testWidgets('each add button adds an item of its kind for typing', (
    tester,
  ) async {
    final text = FakeNoteText('- [ ] milk');
    await pumpEditor(tester, text);

    await tester.tap(find.byTooltip('Add bullet'));
    await tester.pumpAndSettle();
    await tester.typeImeText('note');

    expect(text.text, '- note\n- [ ] milk');
  });

  testWidgets('deleting an item from its menu offers undo', (tester) async {
    final text = FakeNoteText('- [ ] milk\n- [ ] eggs');
    await pumpEditor(tester, text);

    await caretAt(tester, nodeOf<TaskNode>(), 0);
    await tester.tap(find.byTooltip('Item actions'));
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
      SuperEditorInspector.findDocument()!.whereType<TaskNode>(),
      hasLength(2),
    );
    expect(text.edits, isEmpty);
  });

  testWidgets('Bold wraps the selected word', (tester) async {
    final text = FakeNoteText('buy milk');
    await pumpEditor(tester, text);

    await tester.doubleTapInParagraph(nodeOf<ParagraphNode>(), 5);
    await tester.tap(find.byTooltip('Bold (Ctrl+B)'));
    await tester.pumpAndSettle();

    expect(text.text, 'buy **milk**');
  });

  testWidgets('Start list turns the line into a checkbox item', (tester) async {
    final text = FakeNoteText('milk');
    await pumpEditor(tester, text);

    await caretAt(tester, nodeOf<ParagraphNode>(), 0);
    await tester.tap(find.byTooltip('Start list'));
    await tester.pumpAndSettle();

    expect(text.text, startsWith('- [ ] milk'));
  });

  testWidgets('Markdown edit edits every character', (tester) async {
    final text = FakeNoteText('- [ ] milk');
    await pumpEditor(tester, text, mode: NoteMode.markdown);
    expect(find.byType(Checkbox), findsNothing);

    await caretAt(tester, nodeOf<ParagraphNode>(), 4);
    await tester.typeImeText('x');

    expect(text.text, '- [x] milk');
  });

  testWidgets('Read opens a tapped link and edits nothing', (tester) async {
    final text = FakeNoteText('see [site](https://example.com)');
    await pumpEditor(tester, text, mode: NoteMode.read);

    await tester.tapAt(
      tester.getCenter(find.byType(SuperReader)) -
          Offset(tester.getSize(find.byType(SuperReader)).width / 2 - 40, 0),
    );
    await tester.pumpAndSettle();

    expect(links, ['https://example.com']);
    expect(text.edits, isEmpty);
  });
}
