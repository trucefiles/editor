import 'package:test/test.dart';
import 'package:truce_markdown/src/document_tree.dart';
import 'package:truce_markdown/src/edit/clipboard/clipboard_lines.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/shown/rows.dart';
import 'package:truce_markdown/src/edit/shown/selection.dart';
import 'package:truce_markdown/src/edit/shown/shown_document.dart';
import 'package:truce_markdown/src/visible/formatting.dart';

/// [document] after [pasted] over [from] to [to] of its first row; with the
/// selection after.
(String, Selection) _pasted(String document, int from, int to, String pasted) {
  final shown = ShownDocument(DocumentTree.read(document));
  Place place(int offset) => Place((shown.rows.first as TextRow).slot, offset);
  final edited = run(
    shown,
    Paste(
      TextSelection(place(from), place(to)),
      plainLines(pasted, Formatting.plain),
    ),
  );
  return (edited.document.tree.text, edited.selection);
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
    final source = ShownDocument(DocumentTree.read('- **a** b\n\n> *c*'));
    Place place(int row, int offset) =>
        Place((source.rows[row] as TextRow).slot, offset);
    final lines = copiedLines(source, TextSelection(place(0, 0), place(1, 1)));
    final target = ShownDocument(DocumentTree.read('x'));
    final at = TextSelection.caret(
      Place((target.rows.first as TextRow).slot, 1),
    );
    expect(run(target, Paste(at, lines)).document.tree.text, 'x**a** b\n\n*c*');
  });

  test('makes copied links new inline links', () {
    final source = ShownDocument(
      DocumentTree.read('[a][r] www.x.io\n\n[r]: /u'),
    );
    final slot = (source.rows.first as TextRow).slot;
    final lines = copiedLines(
      source,
      TextSelection(Place(slot, 0), Place(slot, 10)),
    );
    final target = ShownDocument(DocumentTree.read('x'));
    final at = TextSelection.caret(
      Place((target.rows.first as TextRow).slot, 0),
    );
    expect(
      run(target, Paste(at, lines)).document.tree.text,
      '[a](/u) www.x.iox',
    );
  });
}
