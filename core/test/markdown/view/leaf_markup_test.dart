import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// How a leaf's Markdown shows: its block marks and inline marks, with
/// the ranges of its syntax.
void main() {
  const syntax = SyntaxMarkup();

  /// The markup of the first leaf of [source], on its text.
  List<MarkupSpan> markupOf(String source) {
    final document = MarkdownDocument.parse(source);
    final view = LeafView.of(document, document.leaves.first);
    return view.markupOf(view.text);
  }

  /// The markup of [source] but its syntax.
  List<MarkupSpan> styles(String source) => [
    for (final span in markupOf(source))
      if (span.markup is! SyntaxMarkup) span,
  ];

  /// The syntax of [source], the text of its only leaf.
  List<String> hidden(String source) => [
    for (final span in markupOf(source))
      if (span.markup is SyntaxMarkup) source.substring(span.start, span.end),
  ];

  group('inline marks', () {
    test('bold, italic, both and strike', () {
      expect(styles('a **b** c'), [const MarkupSpan(BoldMarkup(), 4, 5)]);
      expect(styles('_i_'), [const MarkupSpan(ItalicMarkup(), 1, 2)]);
      expect(styles('***x***'), [
        const MarkupSpan(ItalicMarkup(), 1, 6),
        const MarkupSpan(BoldMarkup(), 3, 4),
      ]);
      expect(styles('~~s~~'), [const MarkupSpan(StrikeMarkup(), 2, 3)]);
      expect(styles('~s~'), [const MarkupSpan(StrikeMarkup(), 1, 2)]);
      expect(hidden('a **b** c'), ['**', '**']);
    });

    test('nested marks', () {
      expect(styles('**a *b* c**'), [
        const MarkupSpan(BoldMarkup(), 2, 9),
        const MarkupSpan(ItalicMarkup(), 5, 6),
      ]);
    });

    test('marks across lines', () {
      expect(markupOf('a *b\nc* d'), [
        const MarkupSpan(ItalicMarkup(), 3, 6),
        const MarkupSpan(syntax, 2, 3),
        const MarkupSpan(syntax, 6, 7),
      ]);
      expect(styles('**a\nb**'), [const MarkupSpan(BoldMarkup(), 2, 5)]);
    });

    test('unclosed or spaced marks stay plain', () {
      expect(markupOf('a ** b'), isEmpty);
      expect(markupOf('**a'), isEmpty);
      expect(markupOf('2 * 3 * 4'), isEmpty);
      expect(markupOf('snake_case_name'), isEmpty);
    });

    test('a backslash escapes a mark', () {
      expect(markupOf(r'\*a*'), [const MarkupSpan(syntax, 0, 1)]);
    });

    test('a character reference shows as its character', () {
      expect(markupOf('a &amp; b'), [
        const MarkupSpan(EntityMarkup('&'), 2, 7),
      ]);
      expect(markupOf('&#35;'), [const MarkupSpan(EntityMarkup('#'), 0, 5)]);
      expect(markupOf('&nosuch;'), isEmpty);
    });

    test('a code span holds no other marks', () {
      expect(markupOf('`a **b**`'), [
        const MarkupSpan(CodeMarkup(), 0, 9),
        const MarkupSpan(syntax, 0, 1),
        const MarkupSpan(syntax, 8, 9),
      ]);
      expect(markupOf(r'`\*`'), [
        const MarkupSpan(CodeMarkup(), 0, 4),
        const MarkupSpan(syntax, 0, 1),
        const MarkupSpan(syntax, 3, 4),
      ]);
    });

    test('links, autolinks and bare urls', () {
      expect(styles('see [it](https://x.org) now'), [
        const MarkupSpan(LinkMarkup('https://x.org'), 5, 7),
      ]);
      expect(hidden('see [it](https://x.org) now'), ['[', '](https://x.org)']);
      expect(styles('<https://x.org>'), [
        const MarkupSpan(LinkMarkup('https://x.org'), 1, 14),
      ]);
      expect(hidden('<https://x.org>'), ['<', '>']);
      expect(styles('go https://x.org/a.'), [
        const MarkupSpan(LinkMarkup('https://x.org/a'), 3, 18),
      ]);
      expect(styles('go www.x.org'), [
        const MarkupSpan(LinkMarkup('http://www.x.org'), 3, 12),
      ]);
    });

    test('a reference link looks up its definition', () {
      expect(styles('[a] and [b]\n\n[a]: https://x.org'), [
        const MarkupSpan(LinkMarkup('https://x.org'), 1, 2),
      ]);
    });

    test('an image shows as one, its description dimmed', () {
      expect(markupOf('![a *b*](i.png)'), [
        const MarkupSpan(ImageMarkup('i.png', 'a b'), 0, 15),
        const MarkupSpan(DimmedMarkup(), 2, 7),
        const MarkupSpan(syntax, 0, 2),
        const MarkupSpan(syntax, 7, 15),
        const MarkupSpan(ItalicMarkup(), 5, 6),
        const MarkupSpan(syntax, 4, 5),
        const MarkupSpan(syntax, 6, 7),
      ]);
    });

    test('raw HTML is dimmed', () {
      expect(markupOf('a <b>x</b>'), [
        const MarkupSpan(DimmedMarkup(), 2, 5),
        const MarkupSpan(DimmedMarkup(), 6, 10),
      ]);
    });

    test("a backslash at a line's end is hidden as syntax", () {
      expect(markupOf('a\\\nb'), [const MarkupSpan(syntax, 1, 2)]);
      expect(markupOf('a\\'), [const MarkupSpan(syntax, 1, 2)]);
      expect(markupOf('a  \nb'), isEmpty);
    });
  });

  group('block marks', () {
    test('a heading', () {
      expect(markupOf('## A *b*'), [
        const MarkupSpan(HeadingMarkup(2), 0, 8),
        const MarkupSpan(syntax, 0, 3),
        const MarkupSpan(ItalicMarkup(), 6, 7),
        const MarkupSpan(syntax, 5, 6),
        const MarkupSpan(syntax, 7, 8),
      ]);
    });

    test("a heading's closing marks are syntax", () {
      expect(markupOf('# a ##'), [
        const MarkupSpan(HeadingMarkup(1), 0, 6),
        const MarkupSpan(syntax, 0, 2),
        const MarkupSpan(syntax, 3, 6),
      ]);
    });

    test("a heading's indent is not in its text", () {
      expect(markupOf('   # a'), [
        const MarkupSpan(HeadingMarkup(1), 0, 3),
        const MarkupSpan(syntax, 0, 2),
      ]);
    });

    test('a heading written as text over an underline', () {
      expect(markupOf('A *b*\n==='), [
        const MarkupSpan(HeadingMarkup(1), 0, 5),
        const MarkupSpan(ItalicMarkup(), 3, 4),
        const MarkupSpan(syntax, 2, 3),
        const MarkupSpan(syntax, 4, 5),
        const MarkupSpan(syntax, 6, 9),
      ]);
      expect(markupOf('a\nb\n---'), [
        const MarkupSpan(HeadingMarkup(2), 0, 3),
        const MarkupSpan(syntax, 4, 7),
      ]);
    });

    test('a quote: its marks are its frame, its text is quoted', () {
      expect(markupOf('> q *i*'), [
        const MarkupSpan(QuoteMarkup(), 0, 5),
        const MarkupSpan(ItalicMarkup(), 3, 4),
        const MarkupSpan(syntax, 2, 3),
        const MarkupSpan(syntax, 4, 5),
      ]);
    });

    test("an item: its marker and box are its frame's", () {
      expect(markupOf('  - [x] a'), isEmpty);
      expect(markupOf('1. *a*'), [
        const MarkupSpan(ItalicMarkup(), 1, 2),
        const MarkupSpan(syntax, 0, 1),
        const MarkupSpan(syntax, 2, 3),
      ]);
    });

    test('a thematic break is dimmed, no item', () {
      expect(markupOf('* * *'), [const MarkupSpan(DimmedMarkup(), 0, 5)]);
    });

    test('code blocks have no inline marks; fences are dimmed', () {
      expect(markupOf('    **a**'), [
        const MarkupSpan(CodeBlockMarkup(), 0, 5),
      ]);
      expect(markupOf('```\n**a**\n```'), [
        const MarkupSpan(CodeBlockMarkup(), 0, 13),
        const MarkupSpan(DimmedMarkup(), 0, 3),
        const MarkupSpan(DimmedMarkup(), 10, 13),
      ]);
      expect(markupOf('~~~ dart\na'), [
        const MarkupSpan(CodeBlockMarkup(), 0, 10),
        const MarkupSpan(DimmedMarkup(), 0, 8),
      ]);
    });

    test('HTML and tables show as source', () {
      expect(markupOf('<div>\n*a*\n</div>'), [
        const MarkupSpan(CodeBlockMarkup(), 0, 16),
      ]);
      expect(markupOf('| a |\n|---|'), [
        const MarkupSpan(CodeBlockMarkup(), 0, 11),
      ]);
    });

    test('definitions and front matter are dimmed', () {
      expect(markupOf('[a]: https://x.org'), [
        const MarkupSpan(DimmedMarkup(), 0, 18),
      ]);
      expect(markupOf('---\na: b\n---'), [
        const MarkupSpan(CodeBlockMarkup(), 0, 12),
        const MarkupSpan(DimmedMarkup(), 0, 12),
      ]);
    });

    test('a blank line has none', () {
      expect(markupOf(''), isEmpty);
    });
  });
}
