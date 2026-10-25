import 'package:test/test.dart';
import 'package:truce_core/src/note/edit/commands/command.dart';
import 'package:truce_core/src/note/edit/shown/rows.dart';
import 'package:truce_core/src/note/edit/shown/selection.dart';
import 'package:truce_core/src/note/edit/shown/shown_note.dart';
import 'package:truce_core/src/note/edit/shown/slot.dart';
import 'package:truce_core/src/note/note_tree.dart';

ShownNote _note(String text) => ShownNote(NoteTree.read(text));

Slot _slot(ShownNote note, int row) => (note.rows[row] as TextRow).slot;

String _delete(String text, (int, int) from, (int, int) to) {
  final note = _note(text);
  return run(
    note,
    DeleteRange(
      TextSelection(
        Place(_slot(note, from.$1), from.$2),
        Place(_slot(note, to.$1), to.$2),
      ),
    ),
  ).note.tree.text;
}

void main() {
  test('Backspace at a paragraph\'s start joins it to the one above', () {
    final note = _note('a\n\n*b*');
    final (note: joined, :selection) = run(
      note,
      JoinWithPrevious(_slot(note, 1)),
    );
    expect(joined.tree.text, 'a*b*');
    expect(selection, TextSelection.caret(Place(_slot(joined, 0), 1)));
  });

  test('Delete at a paragraph\'s end joins the one below', () {
    final note = _note('a\n\nb');
    expect(run(note, JoinWithNext(_slot(note, 0))).note.tree.text, 'ab');
  });

  test('a join across items moves the subitems under the item above', () {
    final note = _note('- a\n- b\n  - c\n- d');
    expect(
      run(note, JoinWithNext(_slot(note, 0))).note.tree.text,
      '- ab\n  - c\n- d',
    );
  });

  test('a join into a parent item keeps its subitem\'s subitems', () {
    final note = _note('- a\n  - b\n    - c\n  - d');
    expect(
      run(note, JoinWithNext(_slot(note, 0))).note.tree.text,
      '- ab\n  - c\n  - d',
    );
  });

  test('a paragraph after a list joins its last item', () {
    final note = _note('- a\n\nb');
    expect(run(note, JoinWithPrevious(_slot(note, 1))).note.tree.text, '- ab');
  });

  test('a delete across blocks removes what lies between', () {
    expect(_delete('ab\n\n---\n\n> c\n\nde', (0, 1), (3, 1)), 'ae');
  });

  test('a delete into code keeps both', () {
    expect(_delete('ab\n\n```\ncd\n```', (0, 1), (1, 1)), 'a\n\n```\nd\n```');
  });

  test('a join into a gap writes the text there', () {
    final tree = NoteTree.read('a\n\nb');
    final note = ShownNote(
      tree,
      gaps: [
        Gap(
          GapId.first,
          container: tree.root.id,
          after: tree.root.children.first.id,
        ),
      ],
    );
    expect(
      run(note, JoinWithPrevious(_slot(note, 2))).note.tree.text,
      'a\n\nb',
    );
    final joined = run(note, JoinWithPrevious(_slot(note, 2))).note;
    expect(joined.gaps, isEmpty);
    expect(joined.rows, hasLength(2));
  });
}
