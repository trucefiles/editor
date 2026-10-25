import 'package:test/test.dart';
import 'package:truce_core/src/note/edit/commands/command.dart';
import 'package:truce_core/src/note/edit/shown/rows.dart';
import 'package:truce_core/src/note/edit/shown/selection.dart';
import 'package:truce_core/src/note/edit/shown/shown_note.dart';
import 'package:truce_core/src/note/note_tree.dart';
import 'package:truce_core/src/note/visible/formatting.dart';

/// [note] after [pasted] over [from] to [to] of its first row; with the
/// selection after.
(String, Selection) _pasted(String note, int from, int to, String pasted) {
  final shown = ShownNote(NoteTree.read(note));
  Place place(int offset) => Place((shown.rows.first as TextRow).slot, offset);
  final edited = run(
    shown,
    Paste(TextSelection(place(from), place(to)), pasted, Formatting.plain),
  );
  return (edited.note.tree.text, edited.selection);
}

void main() {
  test('puts text in literally, over the selection', () {
    expect(_pasted('a b', 1, 2, '**x**').$1, r'a\*\*x\*\*b');
  });

  test('makes a paragraph of each line', () {
    expect(_pasted('ab', 1, 1, 'x\r\ny\rz').$1, 'ax\n\ny\n\nzb');
  });

  test('makes an item of each line in an item', () {
    expect(_pasted('- ab', 1, 1, 'x\ny').$1, '- ax\n- yb');
  });

  test('keeps the lines in code', () {
    expect(_pasted('```\nab\n```', 1, 1, 'x\ny').$1, '```\nax\nyb\n```');
  });

  test('leaves the caret after the text', () {
    final (_, selection) = _pasted('ab', 1, 1, 'x\nyz');
    expect((selection as TextSelection).extent.offset, 2);
  });
}
