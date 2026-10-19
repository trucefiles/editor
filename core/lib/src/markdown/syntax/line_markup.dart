import 'inline_markup.dart';
import 'line_kinds.dart';
import 'markup.dart';

/// The markup of a whole [line] of [kind]: its block marks (heading,
/// quote, list bullet, checkbox) and its inline markup. Code and table
/// lines have no inline markup.
List<MarkupSpan> lineMarkup(String line, LineKind kind) => switch (kind) {
  LineKind.fence => [
    MarkupSpan(const CodeBlockMarkup(), 0, line.length),
    MarkupSpan(const DimmedMarkup(), 0, line.length),
  ],
  LineKind.code ||
  LineKind.table => [MarkupSpan(const CodeBlockMarkup(), 0, line.length)],
  LineKind.plain => _plainMarkup(line),
};

/// The markup of an item's text, the part after its box.
List<MarkupSpan> itemTextMarkup(String text) => inlineMarkup(text);

List<MarkupSpan> _plainMarkup(String line) {
  if (_heading.firstMatch(line) case final match?) {
    return [
      MarkupSpan(HeadingMarkup(match[1]!.length), 0, line.length),
      MarkupSpan(const SyntaxMarkup(), 0, match.end),
      ...inlineMarkup(line, match.end),
    ];
  }
  if (_quote.firstMatch(line) case final match?) {
    return [
      MarkupSpan(const QuoteMarkup(), 0, line.length),
      MarkupSpan(const SyntaxMarkup(), 0, match.end),
      ...inlineMarkup(line, match.end),
    ];
  }
  if (_item.firstMatch(line) case final match?) {
    return [
      MarkupSpan(const SyntaxMarkup(), match[1]!.length, match.end),
      ...inlineMarkup(line, match.end),
    ];
  }
  if (_bullet.firstMatch(line) case final match?) {
    final bullet = match[1]!.length;
    return [
      MarkupSpan(const BulletMarkup(), bullet, bullet + 1),
      ...inlineMarkup(line, match.end),
    ];
  }
  return inlineMarkup(line);
}

final _heading = RegExp(r'^ {0,3}(#{1,6})(?:[ \t]+|$)');
final _quote = RegExp(r'^(?: {0,3}>[ \t]?)+');
final _item = RegExp(r'^([ \t]*)[-*+][ \t]+\[[ xX]\](?:[ \t]|$)');
final _bullet = RegExp(r'^([ \t]*)[-*+][ \t]+');
