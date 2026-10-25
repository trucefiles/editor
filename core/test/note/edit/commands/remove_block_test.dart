import 'package:test/test.dart';
import 'package:truce_core/src/note/edit/commands/command.dart';
import 'package:truce_core/src/note/edit/shown/rows.dart';
import 'package:truce_core/src/note/edit/shown/selection.dart';
import 'package:truce_core/src/note/edit/shown/shown_note.dart';
import 'package:truce_core/src/note/note_tree.dart';

/// [text] after its first block row goes, with the caret after.
(String, TextSelection) _removed(String text) {
  final note = ShownNote(NoteTree.read(text));
  final rule = note.rows.whereType<BlockRow>().first.leaf;
  final edited = run(note, RemoveBlock(rule.id));
  return (edited.note.tree.text, edited.selection as TextSelection);
}

void main() {
  test('a rule goes, the caret at the start of the text after', () {
    final (text, caret) = _removed('a\n\n---\n\nb');
    expect(text, 'a\n\nb');
    expect(caret.extent.offset, 0);
  });

  test('a last rule leaves the caret at the end of the text above', () {
    final (text, caret) = _removed('ab\n\n---');
    expect(text, 'ab');
    expect(caret.extent.offset, 2);
  });

  test('a rule alone in a quote takes the quote with it', () {
    expect(_removed('a\n\n> ---').$1, 'a');
  });
}
