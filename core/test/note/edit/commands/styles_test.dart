import 'package:test/test.dart';
import 'package:truce_core/src/note/edit/commands/command.dart';
import 'package:truce_core/src/note/edit/shown/rows.dart';
import 'package:truce_core/src/note/edit/shown/selection.dart';
import 'package:truce_core/src/note/edit/shown/shown_note.dart';
import 'package:truce_core/src/note/note_tree.dart';
import 'package:truce_core/src/note/visible/formatting.dart';

/// [text] after [format] is toggled from offset [from] of its row
/// [fromRow] to offset [to] of row [toRow] (by default the same row).
String _styled(
  String text,
  TextFormat format,
  int from,
  int to, {
  int fromRow = 0,
  int? toRow,
}) {
  final note = ShownNote(NoteTree.read(text));
  Place place(int row, int offset) =>
      Place((note.rows[row] as TextRow).slot, offset);
  return run(
    note,
    ToggleStyle(
      TextSelection(place(fromRow, from), place(toRow ?? fromRow, to)),
      format,
    ),
  ).note.tree.text;
}

void main() {
  test('goes on a stretch, and off where all of it has it', () {
    expect(_styled('one two', TextFormat.strong, 4, 7), 'one **two**');
    expect(_styled('one **two**', TextFormat.strong, 4, 7), 'one two');
  });

  test('goes on all of a stretch that has it in part', () {
    expect(_styled('**one** two', TextFormat.strong, 0, 7), '**one two**');
  });

  test('acts on each text leaf the selection covers', () {
    expect(
      _styled('one\n\ntwo', TextFormat.emphasis, 2, 1, toRow: 1),
      'on*e*\n\n*t*wo',
    );
  });

  test('code takes the other formats off its text', () {
    expect(_styled('**one** two', TextFormat.code, 0, 3), '`one` two');
  });

  test('code goes on text only, a soft break in it the space it shows', () {
    expect(_styled('ab\ncd', TextFormat.code, 1, 4), 'a`b c`d');
    expect(_styled('ab\\\ncd', TextFormat.code, 1, 4), 'a`b`\\\n`c`d');
    expect(_styled('a`b`\\\n`c`d', TextFormat.code, 1, 4), 'ab\\\ncd');
  });

  test('a bare link takes it whole', () {
    expect(
      _styled('see www.example.com', TextFormat.strong, 6, 9),
      'see **www.example.com**',
    );
  });

  test('a stretch delimiters cannot write snaps to one that can', () {
    expect(_styled('one two', TextFormat.strong, 3, 7), 'one **two**');
  });
}
