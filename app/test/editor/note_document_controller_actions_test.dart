import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/editor/note_document_controller.dart';
import 'package:truce_editor/notes/note_mode.dart';

import 'editor_support.dart';

/// The view model's actions and how it arranges the lines per mode.
void main() {
  late FakeNoteText text;
  late NoteDocumentController note;

  void open(String markdown, {NoteMode mode = NoteMode.visual}) {
    text = FakeNoteText(markdown);
    note = documentOf(text, mode: mode);
    addTearDown(note.dispose);
  }

  LineId idOf(String lineText) =>
      note.lines.lines.firstWhere((line) => line.text == lineText).id;

  test('each add button adds an empty item of its kind to its list', () {
    open('- [ ] a\n- b');
    final buttons = note.entries.whereType<AddItemEntry>().single;

    note.addItem(buttons, ListKind.numbered);

    expect(text.text, '1. \n- [ ] a\n- b');
  });

  test('the new item gets the id the editor puts the caret in', () {
    open('- [ ] a');
    final buttons = note.entries.whereType<AddItemEntry>().single;

    final id = note.addItem(buttons, ListKind.bullet);

    expect(note.lines.lines.first.id, id);
  });

  test('move puts an item below another', () {
    open('- [ ] a\n- [ ] b\n- [ ] c');

    note.move(idOf('a'), target: idOf('c'), below: true);

    expect(text.text, '- [ ] b\n- [ ] c\n- [ ] a');
  });

  test('indent goes under the item above, outdent back', () {
    open('- [ ] a\n- [ ] b');

    note.indent(idOf('b'));
    expect(text.text, '- [ ] a\n  - [ ] b');

    note.outdent(idOf('b'));
    expect(text.text, '- [ ] a\n- [ ] b');
  });

  test('remove can be undone', () {
    open('- [ ] a\n- [ ] b');

    final undo = note.remove(idOf('a'));
    expect(text.text, '- [ ] b');

    expect(note.undo(undo), isTrue);
    expect(text.text, '- [ ] a\n- [ ] b');
  });

  test('a collapsed Done section hides its items', () {
    open('- [ ] a\n- [x] b');
    final list = idOf('a');
    expect(note.shown, contains(idOf('b')));

    note.toggleCollapsed(list);

    final heading = note.entries.whereType<DoneHeadingEntry>().single;
    expect(heading.collapsed, isTrue);
    expect(note.shown, isNot(contains(idOf('b'))));
  });

  test('a table drawn in Visual edit shows its lines on request', () {
    open('| a |\n|---|\n| 1 |');
    expect(note.entries.single, isA<TableEntry>());

    note.showRaw(idOf('| a |'));

    expect(note.entries, everyElement(isA<LineEntry>()));
  });

  test('Markdown edit shows every line as it is', () {
    open('- [ ] a\n- [x] b', mode: NoteMode.markdown);

    expect(note.entries, everyElement(isA<LineEntry>()));
    expect(note.shown, hasLength(2));
  });

  test('Read has the Done section but no add buttons', () {
    open('- [ ] a\n- [x] b', mode: NoteMode.read);

    expect(note.entries.whereType<DoneHeadingEntry>(), hasLength(1));
    expect(note.entries.whereType<AddItemEntry>(), isEmpty);
  });

  test('a mode switch forgets tables shown as lines', () {
    open('| a |\n|---|\n| 1 |');
    note
      ..showRaw(idOf('| a |'))
      ..mode = NoteMode.read
      ..mode = NoteMode.visual;

    expect(note.entries.single, isA<TableEntry>());
  });
}
