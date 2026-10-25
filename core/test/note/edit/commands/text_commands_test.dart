import 'package:test/test.dart';
import 'package:truce_core/src/note/edit/commands/command.dart';
import 'package:truce_core/src/note/edit/commit.dart';
import 'package:truce_core/src/note/edit/shown/rows.dart';
import 'package:truce_core/src/note/edit/shown/selection.dart';
import 'package:truce_core/src/note/edit/shown/shown_note.dart';
import 'package:truce_core/src/note/edit/shown/slot.dart';
import 'package:truce_core/src/note/note_tree.dart';
import 'package:truce_core/src/note/visible/formatting.dart';

ShownNote _note(String text) => ShownNote(NoteTree.read(text));

/// The text slot of row [index].
Slot _slot(ShownNote note, int index) => (note.rows[index] as TextRow).slot;

Edited _type(ShownNote note, int row, int offset, String text) => run(
  note,
  InsertText(Place(_slot(note, row), offset), text, Formatting.plain),
);

/// What each row shows.
List<String> _shown(ShownNote note) => [
  for (final row in note.rows)
    switch (row) {
      TextRow(:final slot) => note.textOf(slot).text,
      BlockRow(:final leaf) => '[${leaf.runtimeType}]',
    },
];

void main() {
  test('typing changes only the line typed on', () {
    final (:note, :selection) = _type(_note('a\nb'), 0, 3, '!');
    expect(note.tree.text, 'a\nb!');
    expect(selection, TextSelection.caret(Place(_slot(note, 0), 4)));
  });

  test('a space typed at the end shows until text follows it', () {
    final spaced = _type(_note('a'), 0, 1, ' ').note;
    expect(spaced.tree.text, 'a');
    expect(_shown(spaced), ['a ']);
    final typed = _type(spaced, 0, 2, 'b').note;
    expect(typed.tree.text, 'a b');
    expect(typed.tails, isEmpty);
  });

  test('a paragraph emptied shows as a gap until it gets text', () {
    final note = _note('a\n\nb');
    final emptied = run(
      note,
      DeleteRange(
        TextSelection(Place(_slot(note, 1), 0), Place(_slot(note, 1), 1)),
      ),
    );
    expect(emptied.note.tree.text, 'a');
    expect(_shown(emptied.note), ['a', '']);
    final gap = _slot(emptied.note, 1);
    expect(gap, isA<GapSlot>());
    expect(emptied.selection, TextSelection.caret(Place(gap, 0)));
    final typed = _type(emptied.note, 1, 0, 'c');
    expect(typed.note.tree.text, 'a\n\nc');
    expect(typed.note.gaps, isEmpty);
    expect(
      typed.selection,
      TextSelection.caret(Place(_slot(typed.note, 1), 1)),
    );
  });

  test('an empty item writes its text once it gets some', () {
    final spaced = _type(_note('- a\n-'), 1, 0, ' ').note;
    expect(spaced.tree.text, '- a\n-');
    expect(_shown(spaced), ['a', ' ']);
    final typed = _type(spaced, 1, 1, 'b').note;
    expect(typed.tree.text, '- a\n- &#32;b');
  });

  test('an item emptied keeps its marker', () {
    final note = _note('- a\n- b');
    final emptied = run(
      note,
      DeleteRange(
        TextSelection(Place(_slot(note, 1), 0), Place(_slot(note, 1), 1)),
      ),
    );
    expect(emptied.note.tree.text, '- a\n-');
    expect(_slot(emptied.note, 1), isA<ItemSlot>());
  });

  test('text typed after a last block without text writes a paragraph', () {
    final note = _note('```\ncode\n```');
    expect(_slot(note, 1), const GapSlot(GapId.end));
    expect(_type(note, 1, 0, 'x').note.tree.text, '```\ncode\n```\nx');
    expect(_type(_note(''), 0, 0, 'x').note.tree.text, 'x');
  });

  test('a gap in a list splits it once it gets text', () {
    final tree = NoteTree.read('1. a\n2. b\n3. c');
    final list = tree.root.children.single;
    final note = ShownNote(
      tree,
      gaps: [
        Gap(
          GapId.first,
          container: list.id,
          after: (list as dynamic).items[1].id,
        ),
      ],
    );
    expect(_shown(note), ['a', 'b', '', 'c']);
    expect(_type(note, 2, 0, 'x').note.tree.text, '1. a\n2. b\n\nx\n\n3. c');
  });

  test('a line break at the end shows until text follows it', () {
    final note = _note('a');
    final broken = run(note, LineBreak(Place(_slot(note, 0), 1))).note;
    expect(broken.tree.text, 'a');
    expect(_shown(broken), ['a\n']);
    expect(_type(broken, 0, 2, 'b').note.tree.text, 'a\\\nb');
  });

  test('a replacement keeps the formatting of what stays', () {
    final note = _note('**helo** you');
    final edited = run(
      note,
      ReplaceText(
        TextSelection(Place(_slot(note, 0), 0), Place(_slot(note, 0), 4)),
        'hello',
      ),
    );
    expect(edited.note.tree.text, '**hello** you');
  });

  test('typing a web address makes it a link', () {
    final linked = _type(_note('see'), 0, 3, ' www.x.org').note;
    expect(linked.tree.text, 'see www.x.org');
    final text = linked.textOf(_slot(linked, 0));
    expect(text.pieces.last.formatting.link?.destination, 'http://www.x.org');
  });
}
