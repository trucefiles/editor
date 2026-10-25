import 'package:test/test.dart';
import 'package:truce_core/src/note/edit/commands/command.dart';
import 'package:truce_core/src/note/edit/commands/heading.dart';
import 'package:truce_core/src/note/edit/shown/rows.dart';
import 'package:truce_core/src/note/edit/shown/selection.dart';
import 'package:truce_core/src/note/edit/shown/shown_note.dart';
import 'package:truce_core/src/note/edit/shown/slot.dart';
import 'package:truce_core/src/note/note_tree.dart';
import 'package:truce_core/src/note/tree/blocks.dart';

ShownNote _note(String text) => ShownNote(NoteTree.read(text));

Slot _slot(ShownNote note, int row) => (note.rows[row] as TextRow).slot;

TextSelection _caret(ShownNote note, int row) =>
    TextSelection.caret(Place(_slot(note, row), 0));

/// The items of [note], in file order.
List<ItemBlock> _items(ShownNote note) => note.tree.leaves
    .map((leaf) => note.tree.parentOf(leaf))
    .whereType<ItemBlock>()
    .toList();

String _after(String text, Command Function(ShownNote note) command) {
  final note = _note(text);
  return run(note, command(note)).note.tree.text;
}

void main() {
  test('a tap on a box checks it', () {
    expect(
      _after('- [ ] a', (n) => Toggle(_items(n).first.id, _caret(n, 0))),
      '- [x] a',
    );
  });

  test('the delete button removes an item with its subitems', () {
    final note = _note('- a\n  - b\n- c');
    final (note: after, :selection) = run(
      note,
      DeleteItem(_items(note).first.id),
    );
    expect(after.tree.text, '- c');
    expect(selection, TextSelection.caret(Place(_slot(after, 0), 0)));
    expect(_after('- a', (n) => DeleteItem(_items(n).first.id)), '');
  });

  test('Add item puts an empty item at the end', () {
    final note = _note('- [x] a');
    final list = note.tree.root.children.single.id;
    final (note: after, :selection) = run(note, AddItem(list));
    expect(after.tree.text, '- [x] a\n- [ ] ');
    expect(selection, TextSelection.caret(Place(_slot(after, 1), 0)));
  });

  test('a drop moves an item with its subitems', () {
    expect(
      _after('- a\n  - b\n- c', (n) {
        final [a, _, c] = [
          for (final row in n.rows)
            n.tree.parentOf(
              n.tree.blockOf((((row as TextRow).slot) as LeafSlot).leaf)!,
            )!,
        ];
        return MoveItem(a.id, c.id, below: true, selection: _caret(n, 0));
      }),
      '- c\n- a\n  - b',
    );
  });

  test('an item of two paragraphs keeps them apart in a tight list', () {
    expect(
      _after('- a\n  - s\n\n  - b\n\n    c', (n) {
        final items = _items(n);
        return MoveItem(
          items[2].id,
          items[0].id,
          below: true,
          selection: _caret(n, 0),
        );
      }),
      '- a\n  - s\n- b\n\n  c',
    );
  });

  test('checked items move to the end of their lists', () {
    expect(
      _after(
        '- [x] a\n- [ ] b\n- [x] c\n- [ ] d',
        (n) => MoveToEnd(_caret(n, 0)),
      ),
      '- [ ] b\n- [ ] d\n- [x] a\n- [x] c',
    );
  });

  test('clearing checked items removes them', () {
    expect(
      _after(
        '- [x] a\n- [ ] b\n\n> - [x] c',
        (n) => ClearChecked(_caret(n, 1)),
      ),
      '- [ ] b',
    );
  });

  test('the heading button cycles none, 1, 2, 3, none', () {
    expect([null, 1, 2, 3, 4].map(nextHeadingLevel), [1, 2, 3, null, null]);
    expect(_after('a', (n) => SetHeading(Place(_slot(n, 0), 0), 2)), '## a');
    expect(
      _after('a\\\nb', (n) => SetHeading(Place(_slot(n, 0), 0), 3)),
      '### a b',
    );
    expect(
      _after('Title\n===', (n) => SetHeading(Place(_slot(n, 0), 0), 2)),
      'Title\n---',
    );
    expect(_after('# a', (n) => SetHeading(Place(_slot(n, 0), 0), null)), 'a');
  });
}
