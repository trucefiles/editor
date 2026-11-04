import 'package:flutter_test/flutter_test.dart';
import 'package:truce_document_editor/src/visual/ui/passed_row.dart';

/// Rows of [heights], one right below the other from 0.
List<RowSpan> rowsOf(List<double> heights) =>
    heights.fold(<RowSpan>[], (rows, height) {
      final top = rows.isEmpty ? 0.0 : rows.last.bottom;
      return [...rows, (top: top, bottom: top + height)];
    });

void main() {
  test('nothing is passed while the copy is on its own place', () {
    expect(passedRow(rowsOf([40, 40, 40]), 1, 40), isNull);
  });

  for (final (heights, own, next, flip) in [
    // Equal rows: half the neighbor's height.
    ([40.0, 40.0, 40.0], 0, 1, 20.0),
    // A short row dragged over a tall one, and the other way round.
    ([20.0, 80.0, 40.0], 0, 1, 40.0),
    ([80.0, 20.0, 40.0], 0, 1, 10.0),
  ]) {
    test('dragged down over $heights, the next row flips at the middle '
        'of the space both take', () {
      final rows = rowsOf(heights);
      final start = rows[own].top;
      // The middle line between the row above the pair and the one below:
      // the copy's middle reaches it after moving [flip].
      final pair = rows[next].bottom - rows[own].top;
      expect(
        start + heights[own] / 2 + flip,
        closeTo(rows[own].top + pair / 2, 0.001),
      );
      expect(passedRow(rows, own, start + flip - 0.1), isNull);
      expect(passedRow(rows, own, start + flip + 0.1), (
        row: next,
        below: true,
      ));
    });
  }

  test('dragged up, a row flips once the copy\'s top passes its middle', () {
    final rows = rowsOf([80, 20, 40]);
    // Own place 2 (top 100); row 1's middle is 90.
    expect(passedRow(rows, 2, 90.1), isNull);
    expect(passedRow(rows, 2, 89.9), (row: 1, below: false));
    // Row 0's middle is 40.
    expect(passedRow(rows, 2, 40.1), (row: 1, below: false));
    expect(passedRow(rows, 2, 39.9), (row: 0, below: false));
  });

  test('far rows count once the copy passes their middle', () {
    final rows = rowsOf([30, 30, 60, 30, 30]);
    // Copy as high as row 0 (30): its bottom passes row 2's middle (90)
    // with its top past 60, row 3's (135) past 105.
    expect(passedRow(rows, 0, 59), (row: 1, below: true));
    expect(passedRow(rows, 0, 61), (row: 2, below: true));
    expect(passedRow(rows, 0, 106), (row: 3, below: true));
    expect(passedRow(rows, 0, 500), (row: 4, below: true));
  });

  test('moving back flips at the same line', () {
    final rows = rowsOf([40, 60, 40]);
    final down = [
      for (final top in [0.0, 29.0, 31.0]) passedRow(rows, 0, top),
    ];
    final back = [
      for (final top in [31.0, 29.0, 0.0]) passedRow(rows, 0, top),
    ];
    expect(back, down.reversed);
  });

  test('rows with space between them flip at their own middles', () {
    final rows = <RowSpan>[(top: 0, bottom: 40), (top: 48, bottom: 88)];
    expect(passedRow(rows, 0, 3.9), isNull);
    expect(passedRow(rows, 0, 27.9), (row: 1, below: false));
    expect(passedRow(rows, 0, 28.1), (row: 1, below: true));
  });

  test('past the middle of the space before the next row, the drop goes '
      'above that row', () {
    // Two lists with a 40 px paragraph between them, at 40 to 80.
    final rows = <RowSpan>[(top: 0, bottom: 40), (top: 80, bottom: 120)];
    expect(passedRow(rows, 0, 19), isNull);
    expect(passedRow(rows, 0, 21), (row: 1, below: false));
    expect(passedRow(rows, 0, 61), (row: 1, below: true));
    // Moving up from the second list, the same, mirrored.
    expect(passedRow(rows, 1, 61), isNull);
    expect(passedRow(rows, 1, 59), (row: 0, below: true));
    expect(passedRow(rows, 1, 19), (row: 0, below: false));
  });
}
