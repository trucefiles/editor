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

  test('a bullet', () {
    expect(lineMarkup('* a', LineKind.plain), [
      const MarkupSpan(BulletMarkup(), 0, 1),
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
