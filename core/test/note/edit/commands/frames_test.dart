import 'package:test/test.dart';
import 'package:truce_core/src/note/edit/commands/command.dart';
import 'package:truce_core/src/note/edit/shown/rows.dart';
import 'package:truce_core/src/note/edit/shown/selection.dart';
import 'package:truce_core/src/note/edit/shown/shown_note.dart';
import 'package:truce_core/src/note/edit/shown/slot.dart';
import 'package:truce_core/src/note/note_tree.dart';
import 'package:truce_core/src/note/tree/blocks.dart';

ShownNote _note(String text) => ShownNote(NoteTree.read(text));

Slot _slot(ShownNote note, int row) => (note.rows[row] as TextRow).slot;

List<String> _shown(ShownNote note) => [
  for (final row in note.rows)
    switch (row) {
      TextRow(:final slot) => note.textOf(slot).text,
      BlockRow(:final leaf) => '[${leaf.runtimeType}]',
    },
];

String _after(String text, Command Function(ShownNote note) command) {
  final note = _note(text);
  return run(note, command(note)).note.tree.text;
}

TextSelection _caret(ShownNote note, int row) =>
    TextSelection.caret(Place(_slot(note, row), 0));

void main() {
  group('Backspace at a frame\'s start', () {
    test('takes a block out of its quote, which splits around it', () {
      expect(
        _after('> a\n>\n> b\n>\n> c', (n) => RemoveFrame(_slot(n, 1))),
        '> a\n\nb\n\n> c',
      );
      expect(_after('> a\n> b', (n) => RemoveFrame(_slot(n, 0))), 'a\nb');
      expect(
        _after('> a\n>\n> b', (n) => RemoveFrame(_slot(n, 0))),
        'a\n\n> b',
      );
    });

    test('makes a first item a paragraph above its list', () {
      expect(_after('- a\n- b', (n) => RemoveFrame(_slot(n, 0))), 'a\n- b');
      expect(
        _after('- a\n  - b\n- c', (n) => RemoveFrame(_slot(n, 0))),
        'a\n- b\n- c',
      );
    });

    test('makes another item a line of the item above', () {
      expect(
        _after('- a\n- b\n- c', (n) => RemoveFrame(_slot(n, 1))),
        '- a\\\n  b\n- c',
      );
      expect(
        _after('- a\n-\n- c', (n) => RemoveFrame(_slot(n, 1))),
        '- a\n- c',
      );
      expect(
        _after('- a\n  - x\n- b', (n) => RemoveFrame(_slot(n, 2))),
        '- a\n  - x\n\n  b',
      );
    });
  });

  test('Enter on an empty item ends the list there, shown only', () {
    final note = _note('- a\n-\n- c');
    final (note: left, :selection) = run(note, LeaveList(_slot(note, 1)));
    expect(left.tree.text, '- a\n- c');
    expect(_shown(left), ['a', '', 'c']);
    expect(selection, TextSelection.caret(Place(_slot(left, 1), 0)));
  });

  group('indent', () {
    test('makes an item a subitem of the one above', () {
      expect(_after('- a\n- b', (n) => Indent(_caret(n, 1))), '- a\n  - b');
      expect(
        _after('- a\n  1. x\n- b', (n) => Indent(_caret(n, 2))),
        '- a\n  1. x\n  2. b',
      );
    });

    test('outdent puts an item after its parent with the items after it', () {
      expect(
        _after('- a\n  - b\n  - c', (n) => Outdent(_caret(n, 1))),
        '- a\n- b\n  - c',
      );
    });

    test('outdent from an empty paragraph in an empty item ends the list', () {
      final tree = NoteTree.read('- a\n-');
      final empty = tree.root.children.single as ListBlock;
      final note = ShownNote(
        tree,
        gaps: [Gap(GapId.first, container: empty.items.last.id, after: null)],
      );
      final gap = TextSelection.caret(const Place(GapSlot(GapId.first), 0));
      final edited = run(note, Outdent(gap));
      expect(edited.note.tree.text, '- a');
      expect(_shown(edited.note), ['a', '']);
    });

    test('outdent at the top takes an item out of its list', () {
      expect(
        _after('1. a\n2. b\n3. c', (n) => Outdent(_caret(n, 1))),
        '1. a\n\nb\n\n3. c',
      );
    });
  });
}
