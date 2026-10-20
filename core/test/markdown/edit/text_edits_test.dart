import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import '../view_support.dart';

/// The mapping from text edits in views back to file lines: lines an
/// edit does not touch keep their bytes, changed lines keep their prefix.
void main() {
  /// [document] with the text of [view] from [start] to [end] replaced
  /// by [text], and the caret after it.
  (MarkdownDocument, LineCaret) replace(
    MarkdownDocument document,
    EditView view,
    int start,
    int end,
    String text,
  ) => document.replaceText(
    (view: view, offset: start),
    (view: view, offset: end),
    text,
  );

  group('in one view', () {
    test('the same text keeps the exact bytes and ids', () {
      final document = MarkdownDocument.parse('*   [X] milk  \n# Head  ');
      final views = [
        leafViewAt(document, '*   [X] milk  '),
        leafViewAt(document, '# Head  '),
      ];

      final same = views.fold(
        document,
        (document, view) =>
            replace(document, view, 0, view.text.length, view.text).$1,
      );

      expect(same.text, document.text);
      expect(
        same.lines.map((line) => line.id),
        document.lines.map((l) => l.id),
      );
    });

    test('new text keeps the prefix as written', () {
      final document = MarkdownDocument.parse('  *   [X] milk\nnext');
      final view = leafViewAt(document, '  *   [X] milk');

      final (changed, caret) = replace(document, view, 0, 4, 'oat milk');

      expect(changed.text, '  *   [X] oat milk\nnext');
      expect(marked(changed, caret), '  *   [X] oat milk|');
    });

    test('text after a marker that ends its line gets a space first', () {
      for (final (source, expected) in [
        ('-\nx', '- a\nx'),
        ('>\n\nx', '> a\n\nx'),
        ('1.\n\nx', '1. a\n\nx'),
      ]) {
        final document = MarkdownDocument.parse(source);
        final view = leafViewAt(document, source.split('\n').first);

        expect(replace(document, view, 0, 0, 'a').$1.text, expected);
      }
    });

    test('a new line gets the prefix that goes on in its blocks', () {
      for (final (source, expected) in [
        ('> a\n> b\n\nc', '> a\n> new\n> b\n\nc'),
        ('- [x] a\n\nc', '- [x] a\n      new\n\nc'),
        ('> 1. a\n\nc', '> 1. a\n>    new\n\nc'),
        ('a\n\nc', 'a\nnew\n\nc'),
      ]) {
        final document = MarkdownDocument.parse(source);
        final view = leafViewAt(document, source.split('\n').first);

        final (changed, caret) = replace(document, view, 1, 1, '\nnew');

        expect(changed.text, expected);
        expect(marked(changed, caret), endsWith('new|'));
      }
    });

    test('lines it keeps stay, with their ids, also below a new line', () {
      final document = MarkdownDocument.parse('a\nb\nc');
      final view = leafViewAt(document, 'a');

      final (changed, caret) = replace(document, view, 2, 2, 'X\n');

      expect(changed.text, 'a\nX\nb\nc');
      expect([
        changed.lines[0].id,
        changed.lines[2].id,
        changed.lines[3].id,
      ], document.lines.map((line) => line.id));
      expect(marked(changed, caret), '|b');
    });

    test('lines no longer there go; the rest keep their bytes', () {
      final document = MarkdownDocument.parse('- a\n  b\n- c');
      final view = leafViewAt(document, '- a');

      final (changed, caret) = replace(document, view, 0, 3, 'z');

      expect(changed.text, '- z\n- c');
      expect(changed.lines.first.id, document.lines.first.id);
      expect(marked(changed, caret), '- z|');
    });

    test(
      'lines like the edited ones keep their ids where it does not reach',
      () {
        final document = MarkdownDocument.parse('```\nx\n\n\n```');
        final [_, _, joined, ...after] = document.lines;
        final view = leafViewAt(document, '```');

        final (changed, caret) = replace(document, view, 5, 6, '');

        expect(changed.text, '```\nx\n\n```');
        expect(
          changed.lines.map((line) => line.id),
          isNot(contains(joined.id)),
        );
        expect(
          changed.lines.skip(2).map((line) => line.id),
          after.map((l) => l.id),
        );
        expect(marked(changed, caret), 'x|');
      },
    );

    test("the first line's text deleted, its marker stays first", () {
      for (final (source, start, end, expected) in [
        ('- a\n  b', 0, 2, '- b'),
        ('- [x] a\n  b\n  c', 0, 4, '- [x] c'),
        ('> a\nb\n> c', 0, 2, '> b\n> c'),
      ]) {
        final document = MarkdownDocument.parse(source);
        final view = leafViewAt(document, source.split('\n').first);

        final (changed, caret) = replace(document, view, start, end, '');

        expect(changed.text, expected, reason: source);
        expect(caret.line, document.lines.first.id, reason: source);
      }
    });

    test('a line break in the text makes a new line, not a space', () {
      final document = MarkdownDocument.parse('a');

      final (changed, _) = replace(
        document,
        leafViewAt(document, 'a'),
        1,
        1,
        '\nb',
      );

      expect(changed.text, 'a\nb');
    });

    test('new lines get ids never used before', () {
      final document = MarkdownDocument.parse('a\nb');
      final view = leafViewAt(document, 'a');
      final (removed, _) = replace(document, view, 1, 3, '');

      final (added, _) = replace(
        removed,
        leafViewAt(removed, 'a'),
        1,
        1,
        '\nc',
      );

      expect(added.text, 'a\nc');
      expect(
        document.lines.map((line) => line.id),
        isNot(contains(added.lines.last.id)),
      );
    });

    test(
      'a carriage return ending a line stays out of the text, in the line',
      () {
        // Documents have `\n` line breaks (TextFile turns the others into
        // it); a stray `\r` at a line's end is kept as it is.
        final document = MarkdownDocument.parse('a\r\nb');
        final view = leafViewAt(document, 'a\r');

        final (changed, caret) = replace(document, view, 0, 1, 'Z');

        expect(view.text, 'a\nb');
        expect(changed.text, 'Z\r\nb');
        expect(caret.offset, 1);
      },
    );
  });

  group('in a raw line view', () {
    test('the whole line is the text, keeping its id', () {
      final document = MarkdownDocument.parse('- [ ] a\nb');
      final view = rawViewAt(document, '- [ ] a');

      final (changed, _) = replace(document, view, 0, view.text.length, 'a');

      expect(changed.text, 'a\nb');
      expect(changed.lines.first.id, document.lines.first.id);
    });

    test('typing a marker makes a line an item', () {
      final document = MarkdownDocument.parse('a');

      final (changed, _) = replace(
        document,
        rawViewAt(document, 'a'),
        0,
        0,
        '- [ ] ',
      );

      expect(changed.text, '- [ ] a');
      expect(changed.outline.items.single.checked, isFalse);
    });

    test('a new line is a plain line', () {
      final document = MarkdownDocument.parse('> a');

      final (changed, caret) = replace(
        document,
        rawViewAt(document, '> a'),
        3,
        3,
        '\nb',
      );

      expect(changed.text, '> a\nb');
      expect(marked(changed, caret), 'b|');
    });
  });

  group('across views', () {
    test('the lines of the views between go', () {
      final document = MarkdownDocument.parse('a\n\nb\n\nc');
      final blanks = [
        for (final line in document.lines.where((line) => line.isBlank))
          LeafView.of(document, document.leafOf(line.id)),
      ];

      final (changed, caret) = document.replaceText(
        (view: leafViewAt(document, 'a'), offset: 1),
        (view: leafViewAt(document, 'c'), offset: 0),
        '',
        removed: [...blanks, leafViewAt(document, 'b')],
      );

      expect(changed.text, 'ac');
      expect(marked(changed, caret), 'a|c');
    });

    test('only the views it names go', () {
      final document = MarkdownDocument.parse('a\n\nb');

      final (changed, _) = document.replaceText(
        (view: leafViewAt(document, 'a'), offset: 1),
        (view: leafViewAt(document, 'b'), offset: 1),
        'X',
      );

      expect(changed.text, 'aX\n');
    });

    test('the rest of the last view goes on in the blocks of the first', () {
      final document = MarkdownDocument.parse('> a\n\n- b\n  c');

      final (changed, caret) = document.replaceText(
        (view: leafViewAt(document, '> a'), offset: 1),
        (view: leafViewAt(document, '- b'), offset: 1),
        '!',
        removed: [leafViewAt(document, '')],
      );

      expect(changed.text, '> a!\n> c');
      expect(marked(changed, caret), '> a!|');
    });
  });
}
