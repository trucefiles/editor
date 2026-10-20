import 'block_syntax.dart';
import 'inline_markup.dart';
import 'line_kinds.dart';
import 'markup.dart';

/// The markup of a whole [line] of [kind]: its block marks (heading,
/// quote, list marker) and its inline markup. Code and table
/// lines have no inline markup. A line [inQuote] without marks of its
/// own (see `MarkdownLines.isQuote`) shows as quoted. A line of a heading
/// written as text over `===` or `---` ([underlined], see
/// `MarkdownLines.underlinedHeadingOf`) shows as the heading, or as its
/// underline's marks.
List<MarkupSpan> lineMarkup(
  String line,
  LineKind kind, {
  bool inQuote = false,
  UnderlinedHeadingLine? underlined,
}) => switch (kind) {
  LineKind.fence => [
    MarkupSpan(const CodeBlockMarkup(), 0, line.length),
    MarkupSpan(const DimmedMarkup(), 0, line.length),
  ],
  LineKind.code ||
  LineKind.table => [MarkupSpan(const CodeBlockMarkup(), 0, line.length)],
  LineKind.plain => switch (underlined) {
    (level: _, isUnderline: true) => [
      MarkupSpan(const SyntaxMarkup(), 0, line.length),
    ],
    (:final level, isUnderline: false) => [
      MarkupSpan(HeadingMarkup(level), 0, line.length),
      ...inlineMarkup(line),
    ],
    null when inQuote && quoteTextStart(line) == null => [
      MarkupSpan(const QuoteMarkup(), 0, line.length),
      ...inlineMarkup(line),
    ],
    null => _plainMarkup(line),
  },
};

/// The markup of an item's text, the part after its box.
List<MarkupSpan> itemTextMarkup(String text) => inlineMarkup(text);

List<MarkupSpan> _plainMarkup(String line) {
  if (headingMark(line) case (:final level, :final textStart)) {
    return [
      MarkupSpan(HeadingMarkup(level), 0, line.length),
      MarkupSpan(const SyntaxMarkup(), 0, textStart),
      ...inlineMarkup(line, textStart),
    ];
  }
  if (quoteTextStart(line) case final textStart?) {
    return [
      MarkupSpan(const QuoteMarkup(), 0, line.length),
      MarkupSpan(const SyntaxMarkup(), 0, textStart),
      ...inlineMarkup(line, textStart),
    ];
  }
  if (ItemSyntax.of(line) case final item?) {
    return [
      MarkupSpan(const SyntaxMarkup(), item.markStart, item.textStart),
      ...inlineMarkup(line, item.textStart),
    ];
  }
  return inlineMarkup(line);
}
