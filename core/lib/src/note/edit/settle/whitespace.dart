/// Where whitespace may go in a leaf's text so that it reads back as
/// shown: Markdown drops it at a leaf's end, beside a line break in the
/// file, and at the inner edges of delimiters.
library;

import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';

/// [text] split into what a leaf can hold and the [tail] Markdown would
/// drop at its end: spaces, tabs and line breaks.
({VisibleText text, VisibleText tail}) withoutTail(VisibleText text) {
  final end =
      Iterable<int>.generate(text.length)
          .lastWhere((offset) => !_blankAt(text, offset), orElse: () => -1) +
      1;
  return (text: text.slice(0, end), tail: text.slice(end, text.length));
}

/// [text] with each line break wrapped in the file that has whitespace
/// or a break beside it shown as a space instead: those lines join.
VisibleText softBreaksBetweenWords(VisibleText text) => VisibleText([
  for (final (offset, piece) in text.placedPieces)
    if (piece is SoftBreakPiece &&
        !(offset > 0 &&
            offset + 1 < text.length &&
            !_blankAt(text, offset - 1) &&
            !_blankAt(text, offset + 1)))
      TextPiece(' ', piece.formatting)
    else
      piece,
]);

/// The formats delimiters write, which cannot start or end at whitespace.
const delimited = [TextFormat.strong, TextFormat.emphasis, TextFormat.strike];

/// [text] with the whitespace at the inner edges of its delimited spans
/// moved out of them.
VisibleText spanEdgesTrimmed(VisibleText text) => delimited.fold(
  text,
  (text, format) => formatRuns(text, format).fold(text, (text, run) {
    final start = _firstWord(text, run.start, run.end);
    final end = _lastWord(text, run.start, run.end);
    return [
      (run.start, start < end ? start : run.end),
      if (start < end) (end, run.end),
    ].fold(
      text,
      (text, edge) => text.reformatted(
        edge.$1,
        edge.$2,
        (formatting) => formatting.withFormat(format, on: false),
      ),
    );
  }),
);

/// The ranges of [text] that have [format], in order.
List<({int start, int end})> formatRuns(VisibleText text, TextFormat format) {
  final runs = <({int start, int end})>[];
  for (final (offset, piece) in text.placedPieces) {
    if (!piece.formatting.has(format)) continue;
    final last = runs.lastOrNull;
    if (last != null && last.end == offset) {
      runs.last = (start: last.start, end: offset + piece.length);
    } else {
      runs.add((start: offset, end: offset + piece.length));
    }
  }
  return runs;
}

/// The offset of the first character from [start] to [end] that is no
/// whitespace; [end] if none is.
int _firstWord(VisibleText text, int start, int end) => Iterable<int>.generate(
  end - start,
  (index) => start + index,
).firstWhere((offset) => !_blankAt(text, offset), orElse: () => end);

/// The offset after the last character from [start] to [end] that is no
/// whitespace; [start] if none is.
int _lastWord(VisibleText text, int start, int end) =>
    Iterable<int>.generate(
      end - start,
      (index) => end - 1 - index,
    ).firstWhere((offset) => !_blankAt(text, offset), orElse: () => start - 1) +
    1;

/// Whether the character at [offset] is a space, tab or line break.
bool _blankAt(VisibleText text, int offset) => switch (text.pieceAt(offset)) {
  TextPiece() => const [' ', '\t'].contains(text.text[offset]),
  SoftBreakPiece() || HardBreakPiece() => true,
  ObjectPiece() => false,
};
