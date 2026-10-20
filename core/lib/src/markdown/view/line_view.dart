import '../line_id.dart';
import '../markdown_line.dart';
import '../markdown_lines.dart';
import '../syntax/block_syntax.dart';
import '../syntax/line_kinds.dart';
import '../syntax/line_markup.dart';
import '../syntax/markup.dart';

/// How a list item shows: its box, bullet or number, at its level.
typedef ItemLook = ({ListKind kind, int depth, bool checked, int? number});

/// How one line of a document shows in an editor: as a list item, which
/// shows its text after the marker, or as a line of text, which shows the
/// whole line. Any editor can show it.
final class LineView {
  const LineView._(
    this.id,
    this.item,
    this.kind,
    this.text, {
    required this.quote,
    required this.underlined,
    required this.held,
  });

  /// How [line] of [document] shows: with [blocks], list items and quotes
  /// show as such, else every line as text. An item shows as one, except
  /// while the caret is in it ([caretLine]) and its marker ends it, so
  /// `-5` can be typed: it is [held] as text until a space follows the
  /// marker or the caret leaves.
  factory LineView.of(
    MarkdownLines document,
    MarkdownLine line, {
    required bool blocks,
    LineId? caretLine,
  }) {
    final item = blocks && document.isItem(line);
    final held = item && line.id == caretLine && line.markEndsLine;
    final asItem = item && !held;
    return LineView._(
      line.id,
      asItem
          ? (
              kind: line.listKind!,
              depth: document.depthOf(line),
              checked: line.isChecked,
              number: document.numberOf(line),
            )
          : null,
      document.kindOf(line),
      line.raw.substring(asItem ? document.textStartOf(line) : 0),
      quote: blocks && !asItem && document.isQuote(line),
      underlined: blocks && !asItem ? document.underlinedHeadingOf(line) : null,
      held: held,
    );
  }

  final LineId id;

  /// How it shows as a list item; `null` as a line of text.
  final ItemLook? item;

  /// The line's kind by its place, e.g. in a code block.
  final LineKind kind;

  /// Whether it shows as a quote.
  final bool quote;

  /// The level of the heading it is a line of, for a heading written as
  /// text over `===` or `---`; `null` for any other line.
  final int? underlined;

  /// Whether it is an item shown as text only because the caret is in it
  /// (see [LineView.of]): it shows otherwise once the caret leaves.
  final bool held;

  /// What it shows of the line: an item's text after its marker, else the
  /// whole line.
  final String text;

  /// The markup of [shown], read as this view reads its [text]: an item's
  /// text, or a whole line of its kind. [shown] may differ from [text],
  /// e.g. while the user types into it before the document has it.
  List<MarkupSpan> markupOf(String shown) => item != null
      ? itemTextMarkup(shown)
      : lineMarkup(shown, kind, inQuote: quote, underlined: underlined);

  /// The url of the link at [offset] in [shown], by its [markupOf]; `null`
  /// if there is none.
  String? linkAt(String shown, int offset) => [
    for (final span in markupOf(shown))
      if (span.markup case LinkMarkup(:final url)
          when span.start <= offset && offset < span.end)
        url,
  ].firstOrNull;
}
