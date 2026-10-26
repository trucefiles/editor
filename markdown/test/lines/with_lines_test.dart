import 'package:test/test.dart';
import 'package:truce_markdown/src/document_tree.dart';

void main() {
  test('a changed line keeps its id and line ending', () {
    final tree = DocumentTree.read('a\r\nb\r\nc');
    final b = tree.lines[1].id;

    final changed = tree.withLines(1, 2, [(id: b, text: 'bx')]);

    expect(changed.text, 'a\r\nbx\r\nc');
    expect(changed.lines[1].id, b);
  });

  test('a new line ends as most lines do', () {
    final tree = DocumentTree.read('a\r\nb\r\nc\nd');

    final changed = tree.withLines(1, 1, [(id: null, text: 'new')]);

    expect(changed.text, 'a\r\nnew\r\nb\r\nc\nd');
  });

  test('a line added at the end gives the last line its ending', () {
    final tree = DocumentTree.read('a\nb');
    final b = tree.lines[1].id;

    final changed = tree.withLines(1, 2, [
      (id: b, text: 'b'),
      (id: null, text: 'c'),
    ]);

    expect(changed.text, 'a\nb\nc');
  });

  test('lines removed at the end leave the line before last', () {
    final tree = DocumentTree.read('a\nb\nc');

    expect(tree.withLines(1, 3, const []).text, 'a');
  });

  test('a line with line breaks becomes as many lines', () {
    final tree = DocumentTree.read('a\nb\nc');
    final b = tree.lines[1].id;

    final changed = tree.withLines(1, 2, [(id: b, text: 'b1\r\nb2\nb3')]);

    expect(changed.text, 'a\nb1\nb2\nb3\nc');
    expect(changed.lines.map((line) => line.text), [
      'a',
      'b1',
      'b2',
      'b3',
      'c',
    ]);
    expect(changed.lines[1].id, b);
  });
}
