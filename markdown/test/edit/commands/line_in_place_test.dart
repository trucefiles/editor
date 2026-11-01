import 'package:test/test.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/view/rows.dart';

import '../support/shown.dart';

/// [text] after Enter on its first block row, selected whole.
Shown _entered(String text) {
  final document = Shown.read(text);
  final block = document.view.rows.whereType<BlockRow>().first.leaf;
  return document.run(LineInPlace(block.id)).document;
}

void main() {
  test('a divider becomes an empty paragraph with the caret', () {
    final document = Shown.read('a\n\n---\n\nb');
    final block = document.view.rows.whereType<BlockRow>().first.leaf;
    final edited = document.run(LineInPlace(block.id));
    expect(edited.document.rows, ['a', '', 'b']);
    expect(edited.selection, edited.document.caret(1, 0));
  });

  test('a separator item becomes an empty item that keeps its box', () {
    expect(
      _entered('- [ ] a\n- [x] ***\n- [ ] b').text,
      '- [ ] a\n- [x] \n- [ ] b',
    );
  });
}
