import 'package:test/test.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/view/rows.dart';

import '../support/shown.dart';

/// [text] after Enter on its first block row, selected whole.
Shown _entered(String text) {
  final document = Shown.read(text);
  final block = document.view.rows.whereType<BlockRow>().first.leaf;
  return document.run(LineAfter(block.id)).document;
}

void main() {
  test('after a divider is an empty paragraph with the caret', () {
    final document = Shown.read('a\n\n---\n\nb');
    final block = document.view.rows.whereType<BlockRow>().first.leaf;
    final edited = document.run(LineAfter(block.id));
    expect(edited.document.rows, ['a', '[DividerNode]', '', 'b']);
    expect(edited.selection, edited.document.caret(2, 0));
  });

  test('after a separator item is a new item with an open box', () {
    expect(
      _entered('- [ ] a\n- [ ] ***\n- [ ] b').text,
      '- [ ] a\n- [ ] ***\n- [ ] \n- [ ] b',
    );
  });
}
