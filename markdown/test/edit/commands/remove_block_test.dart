import 'package:test/test.dart';
import 'package:truce_markdown/src/edit/clipboard_lines.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/selection.dart';
import 'package:truce_markdown/src/view/rows.dart';
import 'package:truce_markdown/src/visible/formatting.dart';

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

  test('typing over a divider puts the text in its place', () {
    final document = Shown.read('a\n\n---\n\nb');
    final divider = document.view.rows.whereType<BlockRow>().first.leaf;
    final edited = document.run(
      TypeOverBlock(divider.id, plainLines('x\ny', Formatting.plain)),
    );
    expect(edited.document.text, 'a\n\nx\n\ny\n\nb');
    expect(edited.selection, edited.document.caret(2, 1));
  });

  test('typing over a divider in an item keeps the item', () {
    final document = Shown.read('- a\n\n  ---');
    final divider = document.view.rows.whereType<BlockRow>().first.leaf;
    final edited = document.run(
      TypeOverBlock(divider.id, plainLines('x', Formatting.plain)),
    );
    expect(edited.document.text, '- a\n\n  x');
  });
}
