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
  });

  /// How [line] of [document] shows: with [blocks], list items and quotes
  /// show as such, else every line as text. An item shows as one, except while the caret is in it ([caretLine]) and its marker
  /// ends it, so `-5` can be typed: it shows as an item once a space
  /// follows the marker.
  factory LineView.of(
    MarkdownLines document,
    MarkdownLine line, {
    required bool blocks,
    LineId? caretLine,
  }) {
    final asItem =
        blocks &&
        document.isItem(line) &&
        !(line.id == caretLine && line.markEndsLine);
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
    );
  }

  final LineId id;

  /// How it shows as a list item; `null` as a line of text.
  final ItemLook? item;

  /// The line's kind by its place, e.g. in a code block.
  final LineKind kind;

  /// Whether it shows as a quote.
  final bool quote;

  /// What it shows of the line: an item's text after its marker, else the
  /// whole line.
  final String text;

  /// The markup of [shown], text this view shows, e.g. as typed into it
  /// before the document has it.
  List<MarkupSpan> markupOf(String shown) => item != null
      ? itemTextMarkup(shown)
      : lineMarkup(shown, kind, inQuote: quote);
}
