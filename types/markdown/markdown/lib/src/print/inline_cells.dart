/// Visible text as the printer handles it: cells, each one thing that
/// prints on its own (a character, a code span, an object, a line
/// break), grouped into links.
library;

import '../tree/inlines.dart';
import '../visible/formatting.dart';
import '../visible/visible_text.dart';
import 'char_classes.dart';

/// The formats delimiters write around text: all but code.
const spanFormats = {TextFormat.strike, TextFormat.strong, TextFormat.emphasis};

/// One thing text prints as, with its formatting.
sealed class Cell {
  const Cell(this.formatting);

  final Formatting formatting;

  /// The span formats it has.
  Set<TextFormat> get spans => formatting.formats.intersection(spanFormats);

  /// The class of the first and of the last character it prints.
  CharClass get first;
  CharClass get last;

  /// Whether span delimiters leave it out at their edges: whitespace.
  bool get isSpace => first == CharClass.whitespace;

  /// The character it stands for in plain text, for autolink rules.
  String get plain;

  /// This cell with its span formats [spans] instead.
  Cell withSpans(Set<TextFormat> spans);

  /// The visible piece it is.
  VisiblePiece get piece;

  Formatting _withSpans(Set<TextFormat> spans) => Formatting({
    ...formatting.formats.difference(spanFormats),
    ...spans,
  }, formatting.link);
}

/// One character of text (a code point).
final class CharCell extends Cell {
  CharCell(this.char, super.formatting);

  final String char;

  @override
  CharClass get first => classOf(char);

  @override
  CharClass get last => first;

  @override
  String get plain => isInvisible(char) ? ';' : char;

  @override
  CharCell withSpans(Set<TextFormat> spans) =>
      CharCell(char, _withSpans(spans));

  @override
  VisiblePiece get piece => TextPiece(char, formatting);
}

/// Code: text that prints as a code span.
final class CodeCell extends Cell {
  CodeCell(this.code, super.formatting);

  final String code;

  @override
  CharClass get first => CharClass.punctuation;

  @override
  CharClass get last => CharClass.punctuation;

  @override
  String get plain => '`';

  @override
  CodeCell withSpans(Set<TextFormat> spans) =>
      CodeCell(code, _withSpans(spans));

  @override
  VisiblePiece get piece => TextPiece(code, formatting);
}

/// An image or inline HTML, printed as written.
final class ObjectCell extends Cell {
  ObjectCell(this.object) : super(object.formatting);

  final ObjectPiece object;

  @override
  CharClass get first => CharClass.punctuation;

  @override
  CharClass get last => CharClass.punctuation;

  @override
  String get plain => objectCharacter;

  @override
  ObjectCell withSpans(Set<TextFormat> spans) =>
      ObjectCell(object.withFormatting(_withSpans(spans)));

  @override
  VisiblePiece get piece => object;
}

/// A line break: soft (the source wrapped here) or hard.
final class BreakCell extends Cell {
  BreakCell(this.breakPiece) : super(breakPiece.formatting);

  /// A [SoftBreakPiece] or [HardBreakPiece].
  final VisiblePiece breakPiece;

  bool get isHard => breakPiece is HardBreakPiece;

  /// The hard break it was read as; `null` for a new or soft one.
  HardBreakInline? get read => switch (breakPiece) {
    HardBreakPiece(:final read) => read,
    _ => null,
  };

  @override
  CharClass get first => CharClass.whitespace;

  @override
  CharClass get last => CharClass.whitespace;

  @override
  String get plain => isHard ? '\n' : ' ';

  @override
  BreakCell withSpans(Set<TextFormat> spans) =>
      BreakCell(breakPiece.withFormatting(_withSpans(spans)));

  @override
  VisiblePiece get piece => breakPiece;
}

/// The cells [text] prints as.
List<Cell> cellsOf(VisibleText text) => [
  for (final piece in text.pieces)
    ...switch (piece) {
      TextPiece(:final text, :final formatting)
          when formatting.has(TextFormat.code) =>
        [CodeCell(text, formatting)],
      TextPiece(:final text, :final formatting) => [
        for (final rune in text.runes)
          CharCell(String.fromCharCode(rune), formatting),
      ],
      final ObjectPiece object => [ObjectCell(object)],
      SoftBreakPiece() || HardBreakPiece() => [BreakCell(piece)],
    },
];

/// The visible text [cells] show.
VisibleText textOf(Iterable<Cell> cells) =>
    VisibleText(cells.map((cell) => cell.piece));

/// One thing at a text's top level: a cell outside links, or a link
/// with its cells.
sealed class Element {
  const Element();

  /// Its cells, in order.
  List<Cell> get cells;
}

/// A cell outside links.
final class PlainElement extends Element {
  const PlainElement(this.cell);

  final Cell cell;

  @override
  List<Cell> get cells => [cell];
}

/// A link: the cells of its text, which all hold [link].
final class LinkElement extends Element {
  LinkElement(this.link, List<Cell> cells) : cells = List.unmodifiable(cells);

  final LinkMark link;

  @override
  final List<Cell> cells;
}

/// [cells] as elements: each run of cells of one link is one.
List<Element> elementsOf(List<Cell> cells) => [
  for (final (index, cell) in cells.indexed)
    if (cell.formatting.link == null)
      PlainElement(cell)
    else if (index == 0 ||
        !identical(cells[index - 1].formatting.link, cell.formatting.link))
      LinkElement(cell.formatting.link!, [
        ...cells
            .skip(index)
            .takeWhile(
              (next) => identical(next.formatting.link, cell.formatting.link),
            ),
      ]),
];
