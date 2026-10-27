import 'package:test/test.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/selection.dart';
import 'package:truce_markdown/src/view/rows.dart';

import '../support/shown.dart';

/// [text] after its first block row goes, with the caret after.
(String, TextSelection) _removed(String text) {
  final document = Shown.read(text);
  final divider = document.view.rows.whereType<BlockRow>().first.leaf;
  final edited = document.run(RemoveBlock(divider.id));
  return (edited.document.text, edited.selection as TextSelection);
}

void main() {
  test('a divider goes, the caret at the start of the text after', () {
    final (text, caret) = _removed('a\n\n---\n\nb');
    expect(text, 'a\n\nb');
    expect(caret.extent.offset, 0);
  });

  test('a last divider leaves the caret in the empty text after it', () {
    final (text, caret) = _removed('ab\n\n---');
    expect(text, 'ab');
    expect(caret.extent.offset, 0);
  });

  test('a divider with no text after it leaves the caret at the end of the '
      'text above', () {
    final document = Shown.read('ab\n\n---\n\n<!--');
    final divider = document.view.rows.whereType<BlockRow>().first.leaf;
    final edited = document.run(RemoveBlock(divider.id));
    expect(edited.selection, edited.document.caret(0, 2));
  });

  test('a divider alone in a quote takes the quote with it', () {
    expect(_removed('a\n\n> ---').$1, 'a');
  });
}
