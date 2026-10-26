import 'package:test/test.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/selection.dart';
import 'package:truce_markdown/src/edit/typing_style.dart';
import 'package:truce_markdown/src/visible/formatting.dart';

import '../support/shown.dart';

({Shown document, Selection selection}) _type(
  Shown document,
  int row,
  int offset,
  String text,
) => document.run(
  InsertText(document.place(row, offset), text, Formatting.plain),
);

TextSelection _range(Shown document, int row, int from, int to) =>
    TextSelection(document.place(row, from), document.place(row, to));

void main() {
  test('typing changes only the line typed on', () {
    final (:document, :selection) = _type(Shown.read('a\nb'), 0, 3, '!');
    expect(document.text, 'a\nb!');
    expect(selection, document.caret(0, 4));
  });

  test('a space typed at the end shows until text follows it', () {
    final spaced = _type(Shown.read('a'), 0, 1, ' ').document;
    expect(spaced.text, 'a');
    expect(spaced.rows, ['a ']);
    expect(_type(spaced, 0, 2, 'b').document.text, 'a b');
  });

  test('a paragraph emptied shows until it gets text', () {
    final document = Shown.read('a\n\nb');
    final emptied = document.run(DeleteRange(_range(document, 1, 0, 1)));
    expect(emptied.document.text, 'a');
    expect(emptied.document.rows, ['a', '']);
    expect(emptied.selection, emptied.document.caret(1, 0));
    final typed = _type(emptied.document, 1, 0, 'c');
    expect(typed.document.text, 'a\n\nc');
    expect(typed.selection, typed.document.caret(1, 1));
  });

  test('an empty item writes its text once it gets some', () {
    final spaced = _type(Shown.read('- a\n-'), 1, 0, ' ').document;
    expect(spaced.text, '- a\n-');
    expect(spaced.rows, ['a', ' ']);
    expect(_type(spaced, 1, 1, 'b').document.text, '- a\n- &#32;b');
  });

  test('an item emptied keeps its marker', () {
    final document = Shown.read('- a\n- b');
    final emptied = document.run(DeleteRange(_range(document, 1, 0, 1)));
    expect(emptied.document.text, '- a\n-');
  });

  test('text typed after a last block without text writes a paragraph', () {
    final document = Shown.read('```\ncode\n```');
    expect(document.rows, ['code', '']);
    expect(_type(document, 1, 0, 'x').document.text, '```\ncode\n```\n\nx');
    expect(_type(Shown.read(''), 0, 0, 'x').document.text, 'x');
  });

  test('an empty paragraph left in a list splits it once it gets text', () {
    final document = Shown.read('1. a\n2. b\n3. c');
    final item = document.run(SplitBlock(document.caret(1, 1))).document;
    final left = item.run(Outdent(item.caret(2, 0))).document;
    expect(left.rows, ['a', 'b', '', 'c']);
    expect(left.text, '1. a\n2. b\n3. c');
    expect(_type(left, 2, 0, 'x').document.text, '1. a\n2. b\n\nx\n\n3. c');
  });

  test('a reference link next to another stays one', () {
    final document = Shown.read('[r]: u\n\nSee [r] and [other][r].');
    final edited = document.run(DeleteRange(_range(document, 1, 5, 13)));
    expect(edited.document.text, '[r]: u\n\nSee [r][][er][r].');
  });

  test('inline HTML left alone on a line, where it would start an HTML '
      'block, is written as text', () {
    final document = Shown.read('<strong>a\n\nb');
    final edited = document.run(DeleteRange(_range(document, 0, 1, 2)));
    expect(edited.document.text, '\\<strong>\n\nb');
    expect(edited.selection, edited.document.caret(0, 1));
  });

  test('a line break between words drops the space after it', () {
    final document = Shown.read('Hello world');
    final edited = document.run(LineBreak(document.caret(0, 5)));
    expect(edited.document.text, 'Hello\\\nworld');
    expect(edited.selection, document.caret(0, 6));
  });

  test('a line break keeps the spaces of code after it', () {
    final document = Shown.read('`a  b`');
    final broken = document.run(LineBreak(document.caret(0, 1))).document;
    expect(broken.rows, ['a\n  b']);
  });

  test('a line break in code ends the code and goes on after it', () {
    final document = Shown.read('`ab`');
    final broken = document.run(LineBreak(document.caret(0, 1))).document;
    expect(broken.text, '`a`\\\n`b`');
  });

  test('a line break at the end shows until text follows it', () {
    final document = Shown.read('a');
    final broken = document.run(LineBreak(document.caret(0, 1))).document;
    expect(broken.text, 'a');
    expect(broken.rows, ['a\n']);
    expect(_type(broken, 0, 2, 'b').document.text, 'a\\\nb');
  });

  test('a replacement keeps the formatting of what stays', () {
    final document = Shown.read('**helo** you');
    final edited = document.run(
      ReplaceText(_range(document, 0, 0, 4), 'hello'),
    );
    expect(edited.document.text, '**hello** you');
  });

  test('typing in an autolink changes where it leads', () {
    String typed(String text, int at, String insert) {
      final document = Shown.read(text);
      final place = document.place(0, at);
      return document
          .run(InsertText(place, insert, typingStyleAt(document.doc, place)))
          .document
          .text;
    }

    expect(
      typed('see <https://a.org/x> now', 12, 'y'),
      'see <https://ya.org/x> now',
    );
    expect(typed('<me@a.org>', 2, 'y'), '<mey@a.org>');
    expect(typed('<https://a.org>', 8, ' '), 'https:// a.org');
  });

  test('a line ending shown by a reference stays a reference', () {
    final document = Shown.read('foo&#10;bar');
    final styled = document
        .run(ToggleStyle(_range(document, 0, 0, 3), TextFormat.strong))
        .document
        .text;
    expect(styled, '**foo**&#10;bar');
  });

  test('a shortcut image stays one with a link after it', () {
    final document = Shown.read('![foo]\n\n[foo]: /x');
    final linked = document
        .run(SetLink(document.caret(0, 1), '', 'u'))
        .document
        .text;
    expect(linked, '![foo][][u](u)\n\n[foo]: /x');
  });

  test('typing a web address makes it a link', () {
    final linked = _type(Shown.read('see'), 0, 3, ' www.x.org').document;
    expect(linked.text, 'see www.x.org');
    expect(
      linked.textOf(0).pieces.last.formatting.link?.destination,
      'http://www.x.org',
    );
  });
}
