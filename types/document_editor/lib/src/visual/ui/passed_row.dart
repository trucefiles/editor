import 'package:collection/collection.dart';

/// The least space between two rows that counts as space; less is
/// rounding of rows right below each other.
const _space = 1.0;

/// A row on screen, top to bottom, as it shows without any gap.
typedef RowSpan = ({double top, double bottom});

/// Where a dragged row goes among [rows] (top to bottom, its own place
/// [own] among them, kept while it is dragged), with its copy's top at
/// [top] and the copy as high as its own place: next to the row returned,
/// below it or above. `null` while the copy is still on its own place.
///
/// The copy's leading edge passes a row once it passes the row's middle
/// as the row shows. Moving up, that is its top edge, at each row's
/// middle as without a gap: the gap opens above the rows passed, so the
/// rows ahead stay where they are. Moving down, the gap opens below the
/// rows passed and the old place stays, so every row past the next one
/// shows a dragged row lower: the copy's bottom edge passes the next
/// row's middle, and for each row after it, its top edge passes the
/// row's middle as without the gap, which is the same line. Where there
/// is space before the row after the farthest one passed (e.g. a
/// paragraph between two lists), past the middle of that space the drop
/// goes above that row.
///
/// For the row right next to the own place, this is the middle of the
/// space the two take together, whatever their heights; for one farther
/// on, the middle of the space it and the open gap take together. The
/// rule holds no state, so moving back flips at the same line.
({int row, bool below})? passedRow(List<RowSpan> rows, int own, double top) {
  final height = rows[own].bottom - rows[own].top;
  if (top > rows[own].top) {
    return _passedDown(rows, own, next: top + height, beyond: top);
  }
  // Moving up is moving down on the rows turned upside down, the copy's
  // top edge leading all the way.
  final last = rows.length - 1;
  final flipped = [
    for (final row in rows.reversed) (top: -row.bottom, bottom: -row.top),
  ];
  return switch (_passedDown(flipped, last - own, next: -top, beyond: -top)) {
    (:final row, :final below) => (row: last - row, below: !below),
    null => null,
  };
}

/// [passedRow] moving down: the copy's edge that counts is at [next] for
/// the row right after the own place and the space before it, at
/// [beyond] for every row and space after that.
({int row, bool below})? _passedDown(
  List<RowSpan> rows,
  int own, {
  required double next,
  required double beyond,
}) {
  double middle(int index) => (rows[index].top + rows[index].bottom) / 2;
  double edgeAt(int index) => index == own + 1 ? next : beyond;
  final passed =
      Iterable<int>.generate(rows.length)
          .skip(own + 1)
          .lastWhereOrNull((i) => edgeAt(i) > middle(i)) ??
      own;
  final after = passed + 1;
  final space = after < rows.length
      ? (from: rows[passed].bottom, to: rows[after].top)
      : null;
  return switch (space) {
    (:final from, :final to)
        when to - from >= _space && edgeAt(after) > (from + to) / 2 =>
      (row: after, below: false),
    _ when passed == own => null,
    _ => (row: passed, below: true),
  };
}
