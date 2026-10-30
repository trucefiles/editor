import 'package:test/test.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/selection.dart';
import 'package:truce_markdown/src/view/rows.dart';

import '../support/shown.dart';

/// [text] after its first block row goes, by Delete or by Backspace if
/// [backward], with the caret after.
(String, TextSelection) _removed(String text, {bool backward = false}) {
  final document = Shown.read(text);
  final divider = document.view.rows.whereType<BlockRow>().first.leaf;
  final edited = document.run(RemoveBlock(divider.id, backward: backward));
  return (edited.document.text, edited.selection as TextSelection);
}

void main() {
  test('by Delete a divider goes, the caret at the start of the text '
      'after', () {
    final (text, caret) = _removed('a\n\n---\n\nb');
    expect(text, 'a\n\nb');
    expect(caret.extent.offset, 0);
  });

  test('by Backspace a divider goes, the caret at the end of the text '
      'above', () {
    final document = Shown.read('ab\n\n---\n\nc');
    final divider = document.view.rows.whereType<BlockRow>().first.leaf;
    final edited = document.run(RemoveBlock(divider.id, backward: true));
    expect(edited.document.text, 'ab\n\nc');
    expect(edited.selection, edited.document.caret(0, 2));
  });

  test('by Backspace a first divider leaves the caret at the start of the '
      'text after', () {
    final (text, caret) = _removed('---\n\nb', backward: true);
    expect(text, 'b');
    expect(caret.extent.offset, 0);
  });

  for (final backward in [true, false]) {
    test("a separator item's divider leaves an empty item with the caret "
        '(${backward ? 'Backspace' : 'Delete'})', () {
      final document = Shown.read('- [ ] a\n- [ ] ***\n- [ ] b');
      final divider = document.view.rows.whereType<BlockRow>().first.leaf;
      final edited = document.run(RemoveBlock(divider.id, backward: backward));
      expect(edited.document.text, '- [ ] a\n- [ ] \n- [ ] b');
      final caret = edited.selection as TextSelection;
      expect(caret.isCaret, isTrue);
      expect(
        edited.document.view.rows.indexWhere(
          (row) => row.leaf.id == caret.extent.leaf,
        ),
        1,
      );
    });
  }

  test('a last divider leaves the caret in the empty text after it', () {
    final (text, caret) = _removed('ab\n\n---');
    expect(text, 'ab');
    expect(caret.extent.offset, 0);
  });

  test('a divider with no text after it leaves the caret at the end of the '
      'text above', () {
    final document = Shown.read('ab\n\n---\n\n<!--');
    final divider = document.view.rows.whereType<BlockRow>().first.leaf;
    final edited = document.run(RemoveBlock(divider.id, backward: false));
    expect(edited.selection, edited.document.caret(0, 2));
  });

  test('a divider alone in a quote takes the quote with it', () {
    expect(_removed('a\n\n> ---').$1, 'a');
  });
}
