import 'package:test/test.dart';
import 'package:truce_markdown/src/edit/clipboard_lines.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/selection.dart';
import 'package:truce_markdown/src/visible/formatting.dart';

import '../support/shown.dart';

/// [text] after [pasted] over [from] to [to] of its first row; with the
/// selection after.
(String, Selection) _pasted(String text, int from, int to, String pasted) {
  final document = Shown.read(text);
  final edited = document.run(
    Paste(
      TextSelection(document.place(0, from), document.place(0, to)),
      plainLines(pasted, Formatting.plain),
    ),
  );
  return (edited.document.text, edited.selection);
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

  test('keeps the styles of copied lines, not their frames', () {
    final source = Shown.read('- **a** b\n\n> *c*');
    final lines = copiedLines(
      source.view,
      TextSelection(source.place(0, 0), source.place(1, 1)),
    );
    final target = Shown.read('x');
    expect(
      target.run(Paste(target.caret(0, 1), lines)).document.text,
      'x**a** b\n\n*c*',
    );
  });

  test('makes copied links new inline links', () {
    final source = Shown.read('[a][r] www.x.io\n\n[r]: /u');
    final lines = copiedLines(
      source.view,
      TextSelection(source.place(0, 0), source.place(0, 10)),
    );
    final target = Shown.read('x');
    expect(
      target.run(Paste(target.caret(0, 0), lines)).document.text,
      '[a](/u) www.x.iox',
    );
  });
}
