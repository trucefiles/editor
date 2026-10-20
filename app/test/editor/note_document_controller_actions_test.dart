import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/editor/checked_items.dart';
import 'package:truce_editor/editor/note_document_controller.dart';
import 'package:truce_editor/editor/note_mode.dart';

import 'editor_support.dart';

/// The view model's actions and how it arranges the note per mode.
void main() {
  late FakeNoteText text;
  late NoteDocumentController note;

  void open(String markdown, {NoteMode mode = NoteMode.visual}) {
    text = FakeNoteText(markdown);
    note = documentOf(text, mode: mode);
    addTearDown(note.dispose);
  }

  /// The first lines of the text the editor shows.
  Set<LineId> shown() => {
    for (final entry in note.entries)
      if (entry case LeafEntry(leaf: final id) || LineEntry(line: final id)) id,
  };

  LineId idOf(String content) => lineWith(note, content);

  test('the add button adds an empty item of the kind next to it', () {
    open('* a\n- [ ] b');
    final button = note.entries.whereType<AddItemEntry>().first;

    note.addItem(button);

    expect(text.text, '* \n* a\n- [ ] b');
  });

  test('the new item gets the id the editor puts the caret in', () {
    open('- [ ] a');
    final button = note.entries.whereType<AddItemEntry>().single;

    final id = note.addItem(button);

    expect(note.document.lines.first.id, id);
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
    expect(shown(), contains(idOf('b')));

    note.toggleCollapsed(list);

    final heading = note.entries.whereType<DoneHeadingEntry>().single;
    expect(heading.collapsed, isTrue);
    expect(shown(), isNot(contains(idOf('b'))));
  });

  test('a table drawn in Visual edit shows its lines on request', () {
    open('| a |\n|---|\n| 1 |');
    expect(note.entries.single, isA<TableEntry>());

    note.showRaw(idOf('| a |'));

    expect(note.entries.single, isA<LeafEntry>());
  });

  test('Markdown edit shows every line as it is', () {
    open('- [ ] a\n- [x] b', mode: NoteMode.markdown);

    expect(note.entries, everyElement(isA<LineEntry>()));
    expect(shown(), hasLength(2));
  });

  test('Visual edit shows each block as its text', () {
    open('- [ ] a\n  more\n\npara');

    expect(note.entries.whereType<LeafEntry>(), hasLength(3));
  });

  test('Enter at the end of an item keeps its done subitems with it', () {
    open('- [ ] a\n  - [x] a1\n- [ ] b');
    final view = note.viewOf(note.entries.whereType<LeafEntry>().first)!;

    note.enter(view, 1);

    expect(text.text, '- [ ] a\n  - [x] a1\n- [ ] \n- [ ] b');
  });

  test('a toggle moves the item down when checked items go to the end', () {
    open('- [ ] a\n- [ ] b');
    note.setCheckedItems(CheckedItems.toEnd);

    note.toggle(idOf('a'));

    expect(text.text, '- [ ] b\n- [x] a');
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
