import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// Inline Markdown with the ranges of its syntax.
void main() {
  const syntax = SyntaxMarkup();

  List<MarkupSpan> styles(String text) => [
    for (final span in inlineMarkup(text))
      if (span.markup is! SyntaxMarkup) span,
  ];

  List<String> hidden(String text) => [
    for (final span in inlineMarkup(text))
      if (span.markup is SyntaxMarkup) text.substring(span.start, span.end),
  ];

  test('bold, italic, both and strike', () {
    expect(styles('a **b** c'), [const MarkupSpan(BoldMarkup(), 4, 5)]);
    expect(styles('_i_'), [const MarkupSpan(ItalicMarkup(), 1, 2)]);
    expect(styles('***x***'), [
      const MarkupSpan(BoldMarkup(), 3, 4),
      const MarkupSpan(ItalicMarkup(), 3, 4),
    ]);
    expect(styles('~~s~~'), [const MarkupSpan(StrikeMarkup(), 2, 3)]);
    expect(hidden('a **b** c'), ['**', '**']);
  });

  test('nested markup', () {
    expect(styles('**a *b* c**'), [
      const MarkupSpan(BoldMarkup(), 2, 9),
      const MarkupSpan(ItalicMarkup(), 5, 6),
    ]);
  });

  test('unclosed or spaced marks stay plain', () {
    expect(inlineMarkup('a ** b'), isEmpty);
    expect(inlineMarkup('**a'), isEmpty);
    expect(inlineMarkup('2 * 3 * 4'), isEmpty);
    expect(inlineMarkup('snake_case_name'), isEmpty);
  });

  test('inline code holds no other markup', () {
    expect(inlineMarkup('`a **b**`'), [
      const MarkupSpan(syntax, 0, 1),
      const MarkupSpan(CodeMarkup(), 1, 8),
      const MarkupSpan(syntax, 8, 9),
    ]);
  });

  test('links, images, autolinks and bare urls', () {
    expect(styles('see [it](https://x.org) now'), [
      const MarkupSpan(LinkMarkup('https://x.org'), 5, 7),
    ]);
    expect(hidden('see [it](https://x.org) now'), ['[', '](https://x.org)']);
    expect(hidden('![alt](a.png)'), ['![', '](a.png)']);
    expect(styles('<https://x.org>'), [
      const MarkupSpan(LinkMarkup('https://x.org'), 1, 14),
    ]);
    expect(styles('go https://x.org/a.'), [
      const MarkupSpan(LinkMarkup('https://x.org/a'), 3, 18),
    ]);
  });

  test('a backslash escapes a mark', () {
    expect(inlineMarkup(r'\*a*'), [const MarkupSpan(syntax, 0, 1)]);
  });
}
