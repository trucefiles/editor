import 'package:test/test.dart';
import 'package:truce_markdown/src/document_tree.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/commands/links.dart';
import 'package:truce_markdown/src/edit/shown/rows.dart';
import 'package:truce_markdown/src/edit/shown/selection.dart';
import 'package:truce_markdown/src/edit/shown/shown_document.dart';

ShownDocument _document(String text) => ShownDocument(DocumentTree.read(text));

Place _at(ShownDocument document, int offset) =>
    Place((document.rows.first as TextRow).slot, offset);

/// [text] after the link dialog sets [shows] linking [url] over [from]
/// to [to] of its first row; with the caret after.
(String, Selection) _linked(
  String text,
  int from,
  int to,
  String shows,
  String url,
) {
  final document = _document(text);
  final edited = run(
    document,
    SetLink(TextSelection(_at(document, from), _at(document, to)), shows, url),
  );
  return (edited.document.tree.text, edited.selection);
}

String _unlinked(String text, int offset) {
  final document = _document(text);
  return run(document, RemoveLink(_at(document, offset))).document.tree.text;
}

void main() {
  group('setting a link', () {
    test('links the selected text, keeping its formats', () {
      expect(_linked('a **b** c', 2, 3, 'b', 'u').$1, 'a **[b](u)** c');
    });

    test('puts in new text, or the url if none, the caret after it', () {
      final (text, selection) = _linked('a b', 2, 2, 'site', 'u');
      expect(text, 'a [site](u)b');
      expect((selection as TextSelection).extent.offset, 6);
      expect(_linked('a b', 2, 3, '', 'u').$1, 'a [u](u)');
    });

    test('keeps a link\'s spelling when its url stays', () {
      expect(
        _linked('[a][r]\n\n[r]: u', 0, 1, 'b', 'u').$1,
        '[b][r]\n\n[r]: u',
      );
    });

    test('changes a link\'s url', () {
      expect(_linked('[a](u)', 0, 1, 'a', 'v').$1, '[a](v)');
    });
  });

  group('removing a link', () {
    test('keeps its text', () {
      expect(_unlinked('x [a **b**](u) y', 3), 'x a **b** y');
      expect(_unlinked('x [ab](u) y', 4), 'x ab y');
    });

    test('is possible on a link, not on text GFM reads as one', () {
      final document = _document('[a](u) www.example.com');
      expect(canRemoveLink(document, _at(document, 0)), isTrue);
      expect(canRemoveLink(document, _at(document, 3)), isFalse);
      expect(canRemoveLink(document, _at(document, 8)), isFalse);
    });
  });
}
