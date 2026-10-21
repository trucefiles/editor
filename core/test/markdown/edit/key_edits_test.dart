import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import '../view_support.dart';

/// What Enter, a line break, Backspace and Delete do to a document.
void main() {
  /// [source] after [key] in the view of line [raw] at [offset], as text
  /// and the caret's line with `|` at the caret.
  (String, String) press(
    String source,
    String raw,
    int offset,
    (MarkdownDocument, LineCaret) Function(
      MarkdownDocument document,
      LeafView view,
      int offset,
    )
    key,
  ) {
    final document = MarkdownDocument.parse(source);
    final (edited, caret) = key(document, leafViewAt(document, raw), offset);
    return (edited.text, marked(edited, caret));
  }

  (String, String) enter(String source, String raw, int offset) => press(
    source,
    raw,
    offset,
    (document, view, offset) => document.enter(view, offset),
  );

  (String, String) lineBreak(
    String source,
    String raw,
    int offset, {
    bool hard = true,
  }) => press(
    source,
    raw,
    offset,
    (document, view, offset) => document.lineBreak(view, offset, hard: hard),
  );

  group('enter', () {
    test('at the end of an item, the new item goes below its subitems '
        'shown elsewhere', () {
      final document = MarkdownDocument.parse('- [ ] a\n  - [x] a1\n- [ ] b');
      final (shown, _) = document.enter(
        leafViewAt(document, '- [ ] a'),
        1,
        shownBelow: lineAt(document, '- [ ] b').id,
      );
      expect(shown.text, '- [ ] a\n  - [x] a1\n- [ ] \n- [ ] b');
      final (alone, _) = document.enter(leafViewAt(document, '- [ ] a'), 1);
      expect(alone.text, shown.text);
    });

    test('at the end of an item, the new item goes above a subitem shown '
        'below it', () {
      final document = MarkdownDocument.parse('- a\n  - a1');
      final (edited, _) = document.enter(
        leafViewAt(document, '- a'),
        1,
        shownBelow: lineAt(document, '  - a1').id,
      );
      expect(edited.text, '- a\n- \n  - a1');
    });

    test('in an item held as text, a new line', () {
      final document = MarkdownDocument.parse('-');
      final view = leafViewAt(document, '-', caret: true);
      expect(view.held, isTrue);
      final (edited, caret) = document.enter(view, 1);
      expect((edited.text, marked(edited, caret)), ('-\n', '|'));
    });

    test('in an item, the rest of the line goes to a new unchecked item', () {
      expect(enter('- [x] abc\n- d', '- [x] abc', 2), (
        '- [x] ab\n- [ ] c\n- d',
        '- [ ] |c',
      ));
      expect(enter('1. ab', '1. ab', 1), ('1. a\n2. b', '2. |b'));
      expect(enter('* a', '* a', 1), ('* a\n* ', '* |'));
      expect(enter('1. [x] ab', '1. [x] ab', 1), (
        '1. [x] a\n2. [ ] b',
        '2. [ ] |b',
      ));
    });

    test("the item's later lines stay as they are", () {
      expect(enter('- abc\n  def', '- abc', 1), ('- a\n- bc\n  def', '- |bc'));
      expect(enter('- abc\n  def\n- g', '- abc', 5), (
        '- abc\n  d\n- ef\n- g',
        '- |ef',
      ));
    });

    test('in a nested item, the new item is beside it', () {
      expect(enter('- a\n  - bc', '  - bc', 1), (
        '- a\n  - b\n  - c',
        '  - |c',
      ));
      expect(enter('> - bc', '> - bc', 1), ('> - b\n> - c', '> - |c'));
    });

    test("at the start of an item's first line, an empty item goes above", () {
      expect(enter('- [x] abc', '- [x] abc', 0), (
        '- [ ] \n- [x] abc',
        '- [x] |abc',
      ));
      expect(enter('- a\n  - b', '  - b', 0), ('- a\n  - \n  - b', '  - |b'));
    });

    test('at the start of a later block of an item, the item splits', () {
      expect(enter('- a\n\n  b', '  b', 0), ('- a\n\n  \n- b', '- |b'));
    });

    test('in an empty nested item, outdents it', () {
      expect(enter('- a\n  -', '  -', 0), ('- a\n-', '-|'));
      expect(enter('- a\n  - [ ] ', '  - [ ] ', 0), ('- a\n- [ ] ', '- [ ] |'));
    });

    test('in an empty item at the top, leaves the list below a blank line', () {
      expect(enter('- a\n-', '-', 0), ('- a\n\n', '|'));
      expect(enter('- a\n- [ ] ', '- [ ] ', 0), ('- a\n\n', '|'));
    });

    test('leaving needs no second blank line, nor one at the top', () {
      expect(enter('- a\n\n-', '-', 0), ('- a\n\n', '|'));
      expect(enter('-\n- a', '-', 0), ('\n- a', '|'));
    });

    test('leaving the list keeps the quote marks', () {
      expect(enter('> - a\n> -', '> -', 0), ('> - a\n>\n>', '>|'));
    });

    test('on a blank line in a quote, leaves the quote', () {
      expect(enter('> a\n> ', '> ', 0), ('> a\n\n', '|'));
      expect(enter('> > a\n> >', '> >', 0), ('> > a\n>\n>', '>|'));
    });

    test("on a blank line in an item's blocks, leaves the item", () {
      expect(enter('- a\n  ', '  ', 0), ('- a\n\n', '|'));
    });

    test('in a paragraph, a new line in it', () {
      expect(enter('a b', 'a b', 1), ('a\n b', '| b'));
      expect(enter('> a b', '> a b', 1), ('> a\n>  b', '> | b'));
    });

    test('anywhere else, a new line', () {
      expect(enter('# h', '# h', 3), ('# h\n', '|'));
      expect(enter('```\ncode\n```', '```', 8), ('```\ncode\n\n```', '|'));
      expect(enter('', '', 0), ('\n', '|'));
    });
  });

  group('paste', () {
    (String, String) paste(String source, String raw, int offset, String text) {
      final document = MarkdownDocument.parse(source);
      final view = leafViewAt(document, raw, caret: true);
      final place = (view: view, offset: offset);
      final (edited, caret) = document.paste(place, place, text);
      return (edited.text, marked(edited, caret));
    }

    test("into an item's text, each further line is an item", () {
      expect(paste('- [ ] milk', '- [ ] milk', 4, ' oat\ntea\ncake'), (
        '- [ ] milk oat\n- [ ] tea\n- [ ] cake',
        '- [ ] cake|',
      ));
      expect(paste('1. a', '1. a', 1, '\nb'), ('1. a\n2. b', '2. b|'));
    });

    test('into an empty item, its kind goes on', () {
      expect(paste('- [ ] ', '- [ ] ', 0, 'eggs\ntea'), (
        '- [ ] eggs\n- [ ] tea',
        '- [ ] tea|',
      ));
    });

    test('in the middle of an item, the rest goes to the last line', () {
      expect(paste('- ab', '- ab', 1, 'x\ny'), ('- ax\n- yb', '- y|b'));
    });

    test('blank lines after the first go', () {
      expect(paste('- a', '- a', 1, '\n\nb\n'), ('- a\n- b', '- b|'));
      expect(paste('- a', '- a', 0, '\nb'), ('- \n- ba', '- b|a'));
      expect(paste('- a', '- a', 1, '\n\n'), ('- a', '- a|'));
    });

    test('anywhere else, the lines go in as they are', () {
      expect(paste('text', 'text', 4, '\nmore'), ('text\nmore', 'more|'));
      expect(paste('> a', '> a', 1, '\nb'), ('> a\n> b', '> b|'));
    });
  });

  group('lineBreak', () {
    test("in an item's text, a backslash and a line at its text column", () {
      expect(lineBreak('- abc', '- abc', 1), ('- a\\\n  bc', '  |bc'));
      expect(lineBreak('1. abc', '1. abc', 1), ('1. a\\\n   bc', '   |bc'));
      expect(lineBreak('> - abc', '> - abc', 1), (
        '> - a\\\n>   bc',
        '>   |bc',
      ));
      expect(lineBreak('- [ ] abc', '- [ ] abc', 3), (
        '- [ ] abc\\\n      ',
        '      |',
      ));
    });

    test('not hard, a plain line in the item', () {
      expect(lineBreak('- abc', '- abc', 1, hard: false), (
        '- a\n  bc',
        '  |bc',
      ));
    });

    test('anywhere else, as Enter', () {
      expect(lineBreak('a', 'a', 1), ('a\n', '|'));
      expect(lineBreak('> a', '> a', 1), ('> a\n> ', '> |'));
      expect(lineBreak('- a\n-', '-', 0), ('- a\n\n', '|'));
    });
  });

  group('joinBackward', () {
    (String, String?)? backspace(String source, String raw, String? above) {
      final document = MarkdownDocument.parse(source);
      final result = document.joinBackward(
        leafViewAt(document, raw),
        above == null ? null : leafViewAt(document, above),
      );
      return switch (result) {
        (final edited, final caret) => (
          edited.text,
          caret == null ? null : marked(edited, caret),
        ),
        null => null,
      };
    }

    test('an empty line above goes; the view stays as it is', () {
      expect(backspace('- [x] a\n\n- b', '- b', ''), ('- [x] a\n- b', '- |b'));
    });

    test('an empty view goes; the caret goes to the end above', () {
      expect(backspace('a\n-', '-', 'a'), ('a', 'a|'));
      expect(backspace('> a\n> -', '> -', '> a'), ('> a', '> a|'));
    });

    test('the first line joins the line above, without its prefix', () {
      expect(backspace('- a\n- b', '- b', '- a'), ('- ab', '- a|b'));
      expect(backspace('> # h\n> b', '> b', '> # h'), ('> # hb', '> # h|b'));
    });

    test('a hard break that ended the line above goes', () {
      expect(backspace('- a\\\n- b', '- b', '- a\\'), ('- ab', '- a|b'));
    });

    test('an escaped backslash above stays', () {
      expect(backspace('- a\\\\\n- b', '- b', '- a\\\\'), (
        '- a\\\\b',
        '- a\\\\|b',
      ));
    });

    test('in Markdown edit, every character above stays', () {
      final document = MarkdownDocument.parse('a\\\nb');
      final [upper, lower] = [
        for (final line in document.lines) RawLineView.of(document, line),
      ];

      expect(document.joinBackward(lower, upper)!.$1.text, 'a\\b');
    });

    test('joins the last line of a view of several lines', () {
      expect(backspace('- a\\\n  b\n- c', '- c', '- a\\'), (
        '- a\\\n  bc',
        '  b|c',
      ));
    });

    test('without a view above, only an empty view goes', () {
      expect(backspace('a\n', '', null), ('a', null));
      expect(backspace('a', 'a', null), isNull);
    });

    test('the last lines never go', () {
      expect(backspace('', '', null), isNull);
      expect(backspace('-', '-', null), isNull);
    });
  });

  group('joinForward', () {
    (String, String?)? delete(String source, String raw, String? below) {
      final document = MarkdownDocument.parse(source);
      final result = document.joinForward(
        leafViewAt(document, raw),
        below == null ? null : leafViewAt(document, below),
      );
      return switch (result) {
        (final edited, final caret) => (
          edited.text,
          caret == null ? null : marked(edited, caret),
        ),
        null => null,
      };
    }

    test('an empty view goes; the line below stays as it is', () {
      expect(delete('\n- [x] b', '', '- [x] b'), ('- [x] b', '- [x] |b'));
      expect(delete('a\n\n> b\n> c', '', '> b'), ('a\n> b\n> c', '> |b'));
    });

    test('an empty line below goes', () {
      expect(delete('a\n\nb', 'a', ''), ('a\nb', 'a|'));
    });

    test('the line below joins, without its prefix and a hard break', () {
      expect(delete('- a\n- b', '- a', '- b'), ('- ab', '- a|b'));
      expect(delete('- a\\\n- b', '- a\\', '- b'), ('- ab', '- a|b'));
    });

    test('without a view below, only an empty view goes', () {
      expect(delete('a\n', '', null), ('a', null));
      expect(delete('a', 'a', null), isNull);
    });
  });

  group('hard breaks', () {
    test('hardBreakBefore: a backslash and line break end at the offset', () {
      expect(hardBreakBefore('a\\\nb', 3), isTrue);
      expect(hardBreakBefore('a\\\nb', 2), isFalse);
      expect(hardBreakBefore('a\nb', 2), isFalse);
      expect(hardBreakBefore('\n', 1), isFalse);
    });

    test('an escaped backslash is no hard break', () {
      expect(hardBreakBefore('a\\\\\nb', 4), isFalse);
      expect(hardBreakAfter('a\\\\\nb', 2), isFalse);
      expect(hardBreakBefore('a\\\\\\\nb', 5), isTrue);
    });

    test('hardBreakAfter: a backslash and line break start at the offset', () {
      expect(hardBreakAfter('a\\\nb', 1), isTrue);
      expect(hardBreakAfter('a\\\nb', 0), isFalse);
      expect(hardBreakAfter('a\\', 1), isFalse);
    });
  });
}
