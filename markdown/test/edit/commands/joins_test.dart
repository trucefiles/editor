import 'package:test/test.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/selection.dart';

import '../support/shown.dart';

String _delete(String text, (int, int) from, (int, int) to) {
  final document = Shown.read(text);
  return document
      .run(
        DeleteRange(
          TextSelection(
            document.place(from.$1, from.$2),
            document.place(to.$1, to.$2),
          ),
        ),
      )
      .document
      .text;
}

String _joinNext(String text) {
  final document = Shown.read(text);
  final end = document.textOf(0).length;
  return document.run(JoinWithNext(document.place(0, end))).document.text;
}

void main() {
  test('Backspace at a paragraph\'s start joins it to the one above', () {
    final document = Shown.read('a\n\n*b*');
    final (document: joined, :selection) = document.run(
      JoinWithPrevious(document.place(1, 0)),
    );
    expect(joined.text, 'a*b*');
    expect(selection, joined.caret(0, 1));
  });

  test('Delete at a paragraph\'s end joins the one below', () {
    expect(_joinNext('a\n\nb'), 'ab');
  });

  test('a join across items moves the subitems under the item above', () {
    expect(_joinNext('- a\n- b\n  - c\n- d'), '- ab\n  - c\n- d');
  });

  test('a join into a parent item keeps its subitem\'s subitems', () {
    expect(_joinNext('- a\n  - b\n    - c\n  - d'), '- ab\n  - c\n  - d');
  });

  test('a paragraph after a list joins its last item', () {
    final document = Shown.read('- a\n\nb');
    expect(
      document.run(JoinWithPrevious(document.place(1, 0))).document.text,
      '- ab',
    );
  });

  test('a delete across blocks removes what lies between', () {
    expect(_delete('ab\n\n---\n\n> c\n\nde', (0, 1), (3, 1)), 'ae');
  });

  test('a delete into code keeps both', () {
    expect(_delete('ab\n\n```\ncd\n```', (0, 1), (1, 1)), 'a\n\n```\nd\n```');
  });

  test('Backspace after code and Delete before it move the caret in', () {
    final document = Shown.read('a\n\n```\ncd\n```\n\nb');
    final back = document.run(JoinWithPrevious(document.place(2, 0)));
    expect(back.document.text, document.text);
    expect(back.selection, back.document.caret(1, 2));
    final forward = document.run(JoinWithNext(document.place(0, 1)));
    expect(forward.document.text, document.text);
    expect(forward.selection, forward.document.caret(1, 0));
  });

  test('a join into an empty paragraph puts the text there', () {
    final document = Shown.read('a\n\nb');
    final gap = document.run(SplitBlock(document.caret(0, 1))).document;
    final joined = gap.run(JoinWithPrevious(gap.place(2, 0))).document;
    expect(joined.text, 'a\n\nb');
    expect(joined.rows, ['a', 'b']);
  });
}
