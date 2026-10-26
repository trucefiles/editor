import 'package:test/test.dart';
import 'package:truce_markdown/src/doc/doc_nodes.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/selection.dart';
import 'package:truce_markdown/src/tree/inlines.dart';
import 'package:truce_markdown/src/visible/visible_text.dart';

import '../support/shown.dart';

/// [text] after its first row, a raw block, closes with [raw] typed in
/// it, the caret in row [caretRow].
({Shown document, Selection selection}) _closed(
  String text,
  String raw, {
  int caretRow = 1,
}) {
  final document = Shown.read(text);
  return document.run(
    CloseRaw(document.leaf(0), raw, document.caret(caretRow, 0)),
  );
}

void main() {
  test('a raw block closed as it was stays the same', () {
    final document = Shown.read('<div>\n\na');
    final closed = document.run(
      CloseRaw(document.leaf(0), '<div>', document.caret(1, 0)),
    );
    expect(closed.document.doc, same(document.doc));
  });

  test('a raw block becomes what its typed text reads as', () {
    final closed = _closed('<div>\n\na', '# T\n\nb');
    expect(closed.document.rows, ['T', 'b', 'a']);
    expect(closed.document.text, '# T\n\nb\n\na');
  });

  test('a raw block typed empty goes; the caret stays', () {
    final document = Shown.read('<div>\n\na');
    final closed = document.run(
      CloseRaw(document.leaf(0), '', document.caret(1, 1)),
    );
    expect(closed.document.text, 'a');
    expect(closed.selection, TextSelection.caret(document.place(1, 1)));
  });

  test('a changed definition leads its reference links there', () {
    final closed = _closed('[a]: /u\n\nsee [a] ![a]', '[a]: /v');
    final text = closed.document.textOf(1);
    final image = (text.pieces.last as ObjectPiece).inline as ImageInline;
    expect(image.destination, '/v');
    expect(text.formattingAt(4).link?.destination, '/v');
    expect(closed.document.text, '[a]: /v\n\nsee [a] ![a]');
  });

  test('a gone definition leaves its reference links written inline', () {
    final closed = _closed('[a]: /u\n\nsee [a]', '');
    expect(closed.document.text, 'see [a](/u)');
  });

  test('HTML typed open is one raw block, as typed', () {
    // What follows it joins it only once read again: see
    // docs/known-limitations.md.
    final document = Shown.read('<div>\n\na');
    final closed = run(
      document.view,
      CloseRaw(document.leaf(0), '<!-- open', document.caret(1, 0)),
    );
    expect(closed.doc.root.children.first, isA<RawNode>());
    expect(closed.doc.root.children.last, isA<ParagraphNode>());
  });
}
