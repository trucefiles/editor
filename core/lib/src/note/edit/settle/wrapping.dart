import 'package:collection/collection.dart';

import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';

/// The longest a paragraph's line gets in the file, its containers'
/// marks included, unless the paragraph's own lines are shorter.
const maxLineWidth = 120;

/// The shortest line width taken as a paragraph's own wrap width:
/// shorter lines are short lines, not wrapped text.
const minWrapWidth = 60;

/// The width [text]'s lines wrap at, given its paragraph's [oldLines] as
/// in the file (none for a new paragraph): its longest line where that
/// is plausibly a wrap width and less than [maxLineWidth].
int wrapWidthOf(List<String> oldLines) =>
    switch (oldLines.map(columnsOf).maxOrNull) {
      final longest? when oldLines.length > 1 && longest >= minWrapWidth =>
        longest < maxLineWidth ? longest : maxLineWidth,
      _ => maxLineWidth,
    };

/// [text] with its lines in [edited] that are longer than [width] (with
/// [prefix] columns of container marks before each) split at single
/// spaces into lines that fit. A word longer than that stays whole;
/// other lines never move.
VisibleText wrapped(
  VisibleText text, {
  required ({int start, int end}) edited,
  required int width,
  required int prefix,
}) {
  final breaks = _lines(text)
      .where((line) => line.start <= edited.end && line.end >= edited.start)
      .expand((line) => _breaksIn(text, line, width: width, prefix: prefix))
      .toSet();
  if (breaks.isEmpty) return text;
  return VisibleText([
    for (final (offset, piece) in text.placedPieces)
      if (piece is TextPiece) ..._splitAt(piece, offset, breaks) else piece,
  ]);
}

typedef _Line = ({int start, int end});

/// The lines of [text]: what lies between its line breaks.
List<_Line> _lines(VisibleText text) {
  final breaks = [
    for (final (offset, piece) in text.placedPieces)
      if (piece is SoftBreakPiece || piece is HardBreakPiece) offset,
  ];
  return [
    for (final (index, end) in [...breaks, text.length].indexed)
      (start: index == 0 ? 0 : breaks[index - 1] + 1, end: end),
  ];
}

/// The offsets of the spaces where [line] breaks to fit [width].
List<int> _breaksIn(
  VisibleText text,
  _Line line, {
  required int width,
  required int prefix,
}) {
  final spaces = [
    for (final offset in Iterable<int>.generate(
      line.end - line.start,
      (index) => line.start + index,
    ))
      if (offset > line.start &&
          offset < line.end - 1 &&
          _singleSpaceAt(text, offset))
        offset,
  ];
  int columns(int start, int end) =>
      prefix + columnsOf(text.text.substring(start, end));
  final breaks = <int>[];
  var start = line.start;
  while (columns(start, line.end) > width) {
    final fits = spaces.lastWhereOrNull(
      (space) => space > start && columns(start, space) <= width,
    );
    final next = fits ?? spaces.firstWhereOrNull((space) => space > start);
    if (next == null) break;
    breaks.add(next);
    start = next + 1;
  }
  return breaks;
}

/// Whether [offset] holds a space between two words, outside code.
bool _singleSpaceAt(VisibleText text, int offset) {
  bool word(int offset) =>
      text.pieceAt(offset) is! SoftBreakPiece &&
      text.pieceAt(offset) is! HardBreakPiece &&
      !const [' ', '\t'].contains(text.text[offset]);
  return text.text[offset] == ' ' &&
      text.pieceAt(offset) is TextPiece &&
      !text.formattingAt(offset).has(TextFormat.code) &&
      word(offset - 1) &&
      word(offset + 1);
}

/// [piece], which starts at [offset], with a line break wrapped in the
/// file at each of [breaks] in it in place of its space.
Iterable<VisiblePiece> _splitAt(TextPiece piece, int offset, Set<int> breaks) {
  final inside = [
    for (final at in breaks)
      if (at >= offset && at < offset + piece.length) at - offset,
  ]..sort();
  if (inside.isEmpty) return [piece];
  final bounds = [-1, ...inside, piece.length];
  return [
    for (final (index, end) in bounds.skip(1).indexed) ...[
      if (index > 0) SoftBreakPiece(piece.formatting),
      TextPiece(piece.text.substring(bounds[index] + 1, end), piece.formatting),
    ],
  ];
}

/// The columns [line] takes, a tab counting to the next multiple of 4.
int columnsOf(String line) => line
    .split('')
    .fold(
      0,
      (columns, char) => char == '\t' ? (columns ~/ 4 + 1) * 4 : columns + 1,
    );
