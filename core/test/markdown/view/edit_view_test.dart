import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import '../view_support.dart';

/// How a leaf, or a line, shows in an editor.
void main() {
  const syntax = SyntaxMarkup();

  group('a leaf view', () {
    test("an item's leaf shows its text, in a frame per item", () {
      final document = MarkdownDocument.parse('- a\n\n  3. **b**');
      final outer = document.lines.first.id;
      final inner = document.lines.last.id;
      final view = leafViewAt(document, '  3. **b**');

      expect(view.text, '**b**');
      expect(view.frames, [
        ItemFrame(
          item: outer,
          kind: ListKind.bullet,
          checked: false,
          number: null,
          showsMarker: false,
        ),
        ItemFrame(
          item: inner,
          kind: ListKind.numbered,
          checked: false,
          number: 3,
          showsMarker: true,
        ),
      ]);
      expect(view.markedItem, view.frames.last);
      expect(view.markupOf(view.text), [
        const MarkupSpan(BoldMarkup(), 2, 3),
        const MarkupSpan(syntax, 0, 2),
        const MarkupSpan(syntax, 3, 5),
      ]);
    });

    test('a checked box shows checked', () {
      final document = MarkdownDocument.parse('- [x] done');
      final frame = leafViewAt(document, '- [x] done').markedItem!;

      expect((frame.kind, frame.checked), (ListKind.checkbox, true));
    });

    test("an item's later leaves show no marker", () {
      final document = MarkdownDocument.parse('- a\n\n  b');

      expect(leafViewAt(document, '  b').markedItem, isNull);
      expect(leafViewAt(document, '  b').frames.single, isA<ItemFrame>());
    });

    test('frames go from the outermost in', () {
      final item = leafViewAt(MarkdownDocument.parse('- > a'), '- > a');
      final quote = leafViewAt(MarkdownDocument.parse('> - a'), '> - a');

      expect(item.text, 'a');
      expect(item.frames.map((frame) => frame.runtimeType), [
        ItemFrame,
        QuoteFrame,
      ]);
      expect(quote.frames.map((frame) => frame.runtimeType), [
        QuoteFrame,
        ItemFrame,
      ]);
      expect((item.quoted, quote.quoted), (true, true));
    });

    test('a quote shows as one leaf, lazy lines in it', () {
      final view = leafViewAt(MarkdownDocument.parse('> q\nlazy'), '> q');

      expect(view.text, 'q\nlazy');
      expect(view.frames, [const QuoteFrame()]);
      expect(view.markupOf(view.text), [const MarkupSpan(QuoteMarkup(), 0, 6)]);
    });

    test('text over an underline shows as a heading', () {
      final view = leafViewAt(MarkdownDocument.parse('Title\n---'), 'Title');

      expect(view.kind, LeafKind.heading);
      expect(view.markupOf(view.text), [
        const MarkupSpan(HeadingMarkup(2), 0, 5),
        const MarkupSpan(syntax, 6, 9),
      ]);
      expect(
        leafViewAt(MarkdownDocument.parse('==\n==='), '==').markupOf('==\n==='),
        [
          const MarkupSpan(HeadingMarkup(1), 0, 2),
          const MarkupSpan(syntax, 3, 6),
        ],
      );
    });

    test('a code block keeps its kind and holds no items', () {
      final view = leafViewAt(MarkdownDocument.parse('```\n- a\n```'), '```');

      expect(view.kind, LeafKind.code);
      expect(view.frames, isEmpty);
      expect(view.text, '```\n- a\n```');
    });

    test('a new line in it lines up with its content', () {
      final view = leafViewAt(MarkdownDocument.parse('> - a'), '> - a');

      expect(view.newLinePrefix('> - '), '>   ');
      expect(view.newLinePrefix('> 12. [x] '), '>         ');
    });

    test('reads the markup of what it shows, e.g. while typing', () {
      final view = leafViewAt(MarkdownDocument.parse('a'), 'a');

      expect(view.markupOf('a *b*'), [
        const MarkupSpan(ItalicMarkup(), 3, 4),
        const MarkupSpan(syntax, 2, 3),
        const MarkupSpan(syntax, 4, 5),
      ]);
    });
  });

  group('a held item', () {
    LeafView viewOf(String source, {bool caret = true}) =>
        leafViewAt(MarkdownDocument.parse(source), source, caret: caret);

    test('an empty item whose marker ends it shows as text while the caret '
        'is in it', () {
      final held = viewOf('-');

      expect(
        (held.held, held.text, held.kind),
        (true, '-', LeafKind.paragraph),
      );
      expect(held.frames, isEmpty);
    });

    test('keeps the frames of the containers around its item', () {
      final held = viewOf('> 1.');

      expect((held.held, held.text), (true, '1.'));
      expect(held.frames, [const QuoteFrame()]);
    });

    test('shows as an item once the caret leaves or a space follows', () {
      expect(viewOf('-', caret: false).held, isFalse);
      expect(viewOf('-', caret: false).markedItem, isNotNull);
      expect(viewOf('- ').held, isFalse);
      expect(viewOf('- ').text, '');
      expect(viewOf('- a').held, isFalse);
      expect(viewOf('a').held, isFalse);
    });
  });

  test('item: the innermost item a leaf is in, also while held', () {
    final document = MarkdownDocument.parse('- a\n  -\n  > b');
    final [a, held, _] = document.lines;

    expect(leafViewAt(document, '  -').item, held.id);
    expect(leafViewAt(document, '  > b').item, a.id);
    expect(leafViewAt(document, '- a').item, a.id);
    expect(leafViewAt(MarkdownDocument.parse('a'), 'a').item, isNull);
  });

  group('caret mapping', () {
    final document = MarkdownDocument.parse('> - abc\n>   def\n\nx');
    final [first, second, blank, _] = document.lines;
    final view = leafViewAt(document, '> - abc');

    test('offsetOf: where a place in a line is in the text', () {
      expect(view.text, 'abc\ndef');
      expect(view.offsetOf((line: first.id, offset: 5)), 1);
      expect(view.offsetOf((line: second.id, offset: 6)), 6);
      expect(view.offsetOf((line: second.id, offset: 7)), 7);
    });

    test("offsetOf: a place in a line's prefix goes to its text's start", () {
      expect(view.offsetOf((line: first.id, offset: 0)), 0);
      expect(view.offsetOf((line: second.id, offset: 1)), 4);
    });

    test('offsetOf: null for a line not in the view', () {
      expect(view.offsetOf((line: blank.id, offset: 0)), isNull);
    });

    test('caretAt: the place in the file of an offset in the text', () {
      expect(view.caretAt(0), (line: first.id, offset: 4));
      expect(view.caretAt(3), (line: first.id, offset: 7));
      expect(view.caretAt(4), (line: second.id, offset: 4));
      expect(view.caretAt(99), (line: second.id, offset: 7));
    });

    test('the two are inverse on the text', () {
      expect(
        [
          for (var offset = 0; offset <= view.text.length; offset++)
            view.offsetOf(view.caretAt(offset)),
        ],
        [for (var offset = 0; offset <= view.text.length; offset++) offset],
      );
    });
  });

  test('tells the link at an offset of what it shows', () {
    final view = leafViewAt(
      MarkdownDocument.parse('- see [docs](https://example.org) now'),
      '- see [docs](https://example.org) now',
    );

    expect(view.linkAt(view.text, 5), 'https://example.org');
    expect(view.linkAt(view.text, 3), isNull);
    expect(view.linkAt(view.text, view.text.indexOf(' now')), isNull);
    expect(view.linkAt('<https://x.org>', 3), 'https://x.org');
  });

  group('a raw line view', () {
    test('shows every character of its line, its prefix as syntax', () {
      final document = MarkdownDocument.parse('- **a**\n> q');
      final item = rawViewAt(document, '- **a**');
      final quote = rawViewAt(document, '> q');

      expect(item.text, '- **a**');
      expect(item.markupOf(item.text), [
        const MarkupSpan(syntax, 0, 2),
        const MarkupSpan(BoldMarkup(), 4, 5),
        const MarkupSpan(syntax, 2, 4),
        const MarkupSpan(syntax, 5, 7),
      ]);
      expect(quote.markupOf(quote.text), [
        const MarkupSpan(syntax, 0, 2),
        const MarkupSpan(QuoteMarkup(), 2, 3),
      ]);
    });

    test("shows its part of its leaf's markup", () {
      final document = MarkdownDocument.parse('**a\nb**\n\nTitle\n===');

      expect(rawViewAt(document, '**a').markupOf('**a'), [
        const MarkupSpan(BoldMarkup(), 2, 3),
        const MarkupSpan(syntax, 0, 2),
      ]);
      expect(rawViewAt(document, 'b**').markupOf('b**'), [
        const MarkupSpan(BoldMarkup(), 0, 1),
        const MarkupSpan(syntax, 1, 3),
      ]);
      expect(rawViewAt(document, 'Title').markupOf('Title'), [
        const MarkupSpan(HeadingMarkup(1), 0, 5),
      ]);
      expect(rawViewAt(document, '===').markupOf('==='), [
        const MarkupSpan(syntax, 0, 3),
      ]);
    });

    test('once its prefix changed, reads as a line of text', () {
      final view = rawViewAt(MarkdownDocument.parse('- *a*'), '- *a*');

      expect(view.markupOf('-*a*'), [
        const MarkupSpan(ItalicMarkup(), 2, 3),
        const MarkupSpan(syntax, 1, 2),
        const MarkupSpan(syntax, 3, 4),
      ]);
    });

    test('new lines in it are plain lines', () {
      final view = rawViewAt(MarkdownDocument.parse('> - a'), '> - a');

      expect(view.newLinePrefix('> - '), '');
    });
  });

  test('a view reads its text as the kind of its block', () {
    final document = MarkdownDocument.parse('# h\n```\ncode\n```');
    expect(leafViewAt(document, '# h').kind, LeafKind.heading);
    expect(rawViewAt(document, 'code').kind, LeafKind.code);
  });
}
