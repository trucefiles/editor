import 'package:test/test.dart';
import 'package:truce_markdown/src/document_tree.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/shown/rows.dart';
import 'package:truce_markdown/src/edit/shown/selection.dart';
import 'package:truce_markdown/src/edit/shown/shown_document.dart';
import 'package:truce_markdown/src/edit/shown/slot.dart';

ShownDocument _document(String text) => ShownDocument(DocumentTree.read(text));

Slot _slot(ShownDocument document, int row) =>
    (document.rows[row] as TextRow).slot;

String _delete(String text, (int, int) from, (int, int) to) {
  final document = _document(text);
  return run(
    document,
    DeleteRange(
      TextSelection(
        Place(_slot(document, from.$1), from.$2),
        Place(_slot(document, to.$1), to.$2),
      ),
    ),
  ).document.tree.text;
}

void main() {
  test('Backspace at a paragraph\'s start joins it to the one above', () {
    final document = _document('a\n\n*b*');
    final (document: joined, :selection) = run(
      document,
      JoinWithPrevious(_slot(document, 1)),
    );
    expect(joined.tree.text, 'a*b*');
    expect(selection, TextSelection.caret(Place(_slot(joined, 0), 1)));
  });

  test('Delete at a paragraph\'s end joins the one below', () {
    final document = _document('a\n\nb');
    expect(
      run(document, JoinWithNext(_slot(document, 0))).document.tree.text,
      'ab',
    );
  });

  test('a join across items moves the subitems under the item above', () {
    final document = _document('- a\n- b\n  - c\n- d');
    expect(
      run(document, JoinWithNext(_slot(document, 0))).document.tree.text,
      '- ab\n  - c\n- d',
    );
  });

  test('a join into a parent item keeps its subitem\'s subitems', () {
    final document = _document('- a\n  - b\n    - c\n  - d');
    expect(
      run(document, JoinWithNext(_slot(document, 0))).document.tree.text,
      '- ab\n  - c\n  - d',
    );
  });

  test('a paragraph after a list joins its last item', () {
    final document = _document('- a\n\nb');
    expect(
      run(document, JoinWithPrevious(_slot(document, 1))).document.tree.text,
      '- ab',
    );
  });

  test('a delete across blocks removes what lies between', () {
    expect(_delete('ab\n\n---\n\n> c\n\nde', (0, 1), (3, 1)), 'ae');
  });

  test('a delete into code keeps both', () {
    expect(_delete('ab\n\n```\ncd\n```', (0, 1), (1, 1)), 'a\n\n```\nd\n```');
  });

  test('a join into a gap writes the text there', () {
    final tree = DocumentTree.read('a\n\nb');
    final document = ShownDocument(
      tree,
      gaps: [
        Gap(
          GapId.first,
          container: tree.root.id,
          after: tree.root.children.first.id,
        ),
      ],
    );
    expect(
      run(document, JoinWithPrevious(_slot(document, 2))).document.tree.text,
      'a\n\nb',
    );
    final joined = run(document, JoinWithPrevious(_slot(document, 2))).document;
    expect(joined.gaps, isEmpty);
    expect(joined.rows, hasLength(2));
  });
}
