import 'package:test/test.dart';
import 'package:truce_core/src/note/edit/commands/command.dart';
import 'package:truce_core/src/note/edit/shown/rows.dart';
import 'package:truce_core/src/note/edit/shown/selection.dart';
import 'package:truce_core/src/note/edit/shown/shown_note.dart';
import 'package:truce_core/src/note/note_tree.dart';

/// [text] after [kind] is set on its rows [from] to [to].
String _framed(String text, FrameKind kind, [int from = 0, int? to]) {
  final note = ShownNote(NoteTree.read(text));
  Place place(int row) => Place((note.rows[row] as TextRow).slot, 0);
  return run(
    note,
    SetFrame(TextSelection(place(from), place(to ?? from)), kind),
  ).note.tree.text;
}

void main() {
  group('a box', () {
    test('goes on items that have none, and off where all have one', () {
      expect(
        _framed('- a\n- [x] b', FrameKind.checkbox, 0, 1),
        '- [ ] a\n- [x] b',
      );
      expect(_framed('- [ ] a\n- [x] b', FrameKind.checkbox, 0, 1), '- a\n- b');
    });

    test('makes text a list of boxes', () {
      expect(_framed('a\n\nb', FrameKind.checkbox, 0, 1), '- [ ] a\n- [ ] b');
    });
  });

  group('bullet or numbered', () {
    test('changes the whole list', () {
      expect(_framed('- a\n- b', FrameKind.numbered, 1), '1. a\n2. b');
    });

    test('of the list\'s own kind takes the items out of it', () {
      expect(
        _framed('1. a\n2. b\n3. c', FrameKind.numbered, 1),
        '1. a\n\nb\n\n3. c',
      );
    });

    test('of the list\'s own kind leaves an empty item\'s place', () {
      final note = ShownNote(NoteTree.read('1. a\n2.\n3. b'));
      final caret = TextSelection.caret(
        Place((note.rows[1] as TextRow).slot, 0),
      );
      final edited = run(note, SetFrame(caret, FrameKind.numbered));
      expect(edited.note.tree.text, '1. a\n\n3) b');
      final at = (edited.selection as TextSelection).extent;
      expect(edited.note.rowOf(at.slot), 1);
    });

    test('makes text items, joining a list of its kind', () {
      expect(_framed('a', FrameKind.bullet), '- a');
      expect(_framed('- a\n\nb', FrameKind.bullet, 1), '- a\n- b');
    });
  });

  group('a quote', () {
    test('wraps blocks, and goes off where all are quoted', () {
      expect(_framed('a\n\nb', FrameKind.quote, 0, 1), '> a\n>\n> b');
      expect(_framed('> a\n>\n> b', FrameKind.quote, 0), 'a\n\n> b');
    });

    test('in a list wraps the items\' text', () {
      expect(_framed('- a\n  - b', FrameKind.quote), '- > a\n  - b');
    });
  });
}
