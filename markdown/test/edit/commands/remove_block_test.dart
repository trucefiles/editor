import 'package:test/test.dart';
import 'package:truce_markdown/src/document_tree.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/shown/rows.dart';
import 'package:truce_markdown/src/edit/shown/selection.dart';
import 'package:truce_markdown/src/edit/shown/shown_document.dart';

/// [text] after its first block row goes, with the caret after.
(String, TextSelection) _removed(String text) {
  final document = ShownDocument(DocumentTree.read(text));
  final rule = document.rows.whereType<BlockRow>().first.leaf;
  final edited = run(document, RemoveBlock(rule.id));
  return (edited.document.tree.text, edited.selection as TextSelection);
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
