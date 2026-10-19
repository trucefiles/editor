import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// Block marks of a line, with its inline markup.
void main() {
  const syntax = SyntaxMarkup();

  test('a heading', () {
    expect(lineMarkup('## A *b*', LineKind.plain), [
      const MarkupSpan(HeadingMarkup(2), 0, 8),
      const MarkupSpan(syntax, 0, 3),
      const MarkupSpan(syntax, 5, 6),
      const MarkupSpan(ItalicMarkup(), 6, 7),
      const MarkupSpan(syntax, 7, 8),
    ]);
  });

  test('a quote', () {
    expect(lineMarkup('> q', LineKind.plain), [
      const MarkupSpan(QuoteMarkup(), 0, 3),
      const MarkupSpan(syntax, 0, 2),
    ]);
  });

  test('a checkbox item as text: its box is syntax', () {
    expect(lineMarkup('  - [x] a', LineKind.plain), [
      const MarkupSpan(syntax, 2, 8),
    ]);
  });

  test('a bullet or number as text: its marker is syntax', () {
    expect(lineMarkup('* a', LineKind.plain), [const MarkupSpan(syntax, 0, 2)]);
    expect(lineMarkup(' 1. a', LineKind.plain), [
      const MarkupSpan(syntax, 1, 4),
    ]);
  });

  test('a thematic break is no list item', () {
    expect(lineMarkup('* * *', LineKind.plain), isEmpty);
  });

  test('a heading may start with up to three spaces', () {
    expect(lineMarkup('   # a', LineKind.plain), [
      const MarkupSpan(HeadingMarkup(1), 0, 6),
      const MarkupSpan(syntax, 0, 5),
    ]);
  });

  test('code and table lines have no inline markup', () {
    expect(lineMarkup('**a**', LineKind.code), [
      const MarkupSpan(CodeBlockMarkup(), 0, 5),
    ]);
    expect(lineMarkup('```', LineKind.fence), [
      const MarkupSpan(CodeBlockMarkup(), 0, 3),
      const MarkupSpan(DimmedMarkup(), 0, 3),
    ]);
  });
}
