import 'package:collection/collection.dart';

/// The least space between two rows that counts as space; less is
/// rounding of rows right below each other.
const _space = 1.0;

/// A row on screen, top to bottom, as it shows without any gap.
typedef RowSpan = ({double top, double bottom});

/// Where a dragged row goes among [rows] (top to bottom, its own place
/// [own] among them, kept while it is dragged), with its copy's top at
/// [top] and the copy as high as its own place: next to the row returned,
/// below it or above. Moving down, the copy's bottom edge leads: a row is
/// passed once that edge passes its middle, and the row after the
/// farthest one passed is reached once the edge passes the middle of the
/// space before it, if there is space (e.g. a paragraph between two
/// lists). Moving up, the copy's top edge leads alike. `null` while the
/// copy is still on its own place.
///
/// For the row right next to the own place, this is the middle of the
/// space the two take together, whatever their heights; the rule holds no
/// state, so moving back flips at the same line.
({int row, bool below})? passedRow(List<RowSpan> rows, int own, double top) {
  final height = rows[own].bottom - rows[own].top;
  if (top > rows[own].top) return _passedDown(rows, own, top + height);
  // Moving up is moving down on the rows turned upside down.
  final last = rows.length - 1;
  final flipped = [
    for (final row in rows.reversed) (top: -row.bottom, bottom: -row.top),
  ];
  return switch (_passedDown(flipped, last - own, -top)) {
    (:final row, :final below) => (row: last - row, below: !below),
    null => null,
  };
}

/// [passedRow] moving down, the copy's bottom edge at [edge].
({int row, bool below})? _passedDown(List<RowSpan> rows, int own, double edge) {
  double middle(int index) => (rows[index].top + rows[index].bottom) / 2;
  final passed =
      Iterable<int>.generate(rows.length)
          .skip(own + 1)
          .lastWhereOrNull((i) => edge > middle(i)) ??
      own;
  final next = passed + 1;
  final space = next < rows.length
      ? (from: rows[passed].bottom, to: rows[next].top)
      : null;
  return switch (space) {
    (:final from, :final to)
        when to - from >= _space && edge > (from + to) / 2 =>
      (row: next, below: false),
    _ when passed == own => null,
    _ => (row: passed, below: true),
  };
}
