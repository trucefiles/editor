import 'package:test/test.dart';
import 'package:truce_core/src/note/edit/commands/command.dart';
import 'package:truce_core/src/note/edit/shown/rows.dart';
import 'package:truce_core/src/note/edit/shown/selection.dart';
import 'package:truce_core/src/note/edit/shown/shown_note.dart';
import 'package:truce_core/src/note/edit/shown/slot.dart';
import 'package:truce_core/src/note/note_tree.dart';
import 'package:truce_core/src/note/tree/blocks.dart';
import 'package:truce_core/src/note/visible/formatting.dart';

ShownNote _note(String text, {DoneSections? done}) =>
    ShownNote(NoteTree.read(text), done: done);

Slot _slot(ShownNote note, int row) => (note.rows[row] as TextRow).slot;

List<String> _shown(ShownNote note) => [
  for (final row in note.rows)
    switch (row) {
      TextRow(:final slot) => note.textOf(slot).text,
      BlockRow(:final leaf) => '[${leaf.runtimeType}]',
    },
];

({ShownNote note, Selection selection}) _enter(
  ShownNote note,
  int row,
  int offset,
) =>
    run(note, SplitBlock(TextSelection.caret(Place(_slot(note, row), offset))));

void main() {
  test('Enter in a paragraph starts a new one with the text after it', () {
    final (:note, :selection) = _enter(_note('ab'), 0, 1);
    expect(note.tree.text, 'a\n\nb');
    expect(selection, TextSelection.caret(Place(_slot(note, 1), 0)));
  });

  test('Enter at a paragraph\'s end shows an empty one below', () {
    final (:note, :selection) = _enter(_note('a\n\nb'), 0, 1);
    expect(note.tree.text, 'a\n\nb');
    expect(_shown(note), ['a', '', 'b']);
    expect(selection, TextSelection.caret(Place(_slot(note, 1), 0)));
    final typed = run(
      note,
      InsertText(Place(_slot(note, 1), 0), 'x', Formatting.plain),
    );
    expect(typed.note.tree.text, 'a\n\nx\n\nb');
  });

  test('Enter at a paragraph\'s start shows an empty one above', () {
    final (:note, :selection) = _enter(_note('a\n\nb'), 1, 0);
    expect(note.tree.text, 'a\n\nb');
    expect(_shown(note), ['a', '', 'b']);
    expect(selection, TextSelection.caret(Place(_slot(note, 2), 0)));
  });

  test('Enter twice shows two empty paragraphs in order', () {
    final once = _enter(_note('a'), 0, 1);
    final twice = run(once.note, SplitBlock(once.selection as TextSelection));
    expect(_shown(twice.note), ['a', '', '']);
    expect(
      twice.selection,
      TextSelection.caret(Place(_slot(twice.note, 2), 0)),
    );
  });

  test('Enter after a heading starts a paragraph', () {
    final (:note, selection: _) = _enter(_note('# Title'), 0, 5);
    expect(note.tree.text, '# Title');
    expect(_shown(note), ['Title', '']);
    expect(note.tree.root.children.single, isA<HeadingBlock>());
  });

  test('Enter in an item makes a new item with the text after the caret', () {
    final (:note, :selection) = _enter(_note('- ab\n  - c'), 0, 1);
    expect(note.tree.text, '- a\n- b\n  - c');
    expect(selection, TextSelection.caret(Place(_slot(note, 1), 0)));
  });

  test('Enter at an item\'s end makes an empty item', () {
    final (:note, :selection) = _enter(_note('- [x] a'), 0, 1);
    expect(note.tree.text, '- [x] a\n- [ ] ');
    expect(_slot(note, 1), isA<ItemSlot>());
    expect(selection, TextSelection.caret(Place(_slot(note, 1), 0)));
  });

  test('Enter at an item\'s start makes an empty item above', () {
    final (:note, :selection) = _enter(_note('- a'), 0, 0);
    expect(note.tree.text, '-\n- a');
    expect(selection, TextSelection.caret(Place(_slot(note, 1), 0)));
  });

  test('Enter in a Done section makes a checked item right below', () {
    final (:note, selection: _) = _enter(
      _note('- [x] a\n- [ ] b', done: DoneSections()),
      1,
      1,
    );
    expect(note.tree.text, '- [x] a\n- [x] \n- [ ] b');
    expect(_shown(note), ['b', 'a', '']);
  });

  test('Enter in code is a line break in it', () {
    expect(
      _enter(_note('```\nab\n```'), 0, 1).note.tree.text,
      '```\na\nb\n```',
    );
  });

  test('Enter over a selection splits where its text was', () {
    final note = _note('abcd');
    final edited = run(
      note,
      SplitBlock(
        TextSelection(Place(_slot(note, 0), 1), Place(_slot(note, 0), 3)),
      ),
    );
    expect(edited.note.tree.text, 'a\n\nd');
  });

  test('Shift+Enter over a selection puts a line break for its text', () {
    final note = _note('abcd');
    final edited = run(
      note,
      LineBreak(
        TextSelection(Place(_slot(note, 0), 1), Place(_slot(note, 0), 3)),
      ),
    );
    expect(edited.note.tree.text, 'a\\\nd');
  });
}
