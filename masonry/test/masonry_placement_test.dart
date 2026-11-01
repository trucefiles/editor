import 'package:flutter_test/flutter_test.dart';
import 'package:truce_masonry/src/masonry_columns.dart';
import 'package:truce_masonry/src/masonry_placement.dart';

void main() {
  /// A placement of items with [extents], all measured.
  MasonryPlacement measured(List<double> extents, {int columns = 2}) {
    final placement = MasonryPlacement(columns: columns, gap: 10)
      ..count = extents.length;
    for (final (index, extent) in extents.indexed) {
      placement.measure(index, extent);
    }
    return placement;
  }

  group('columns', () {
    test('as many as fit the widest column, equally wide', () {
      final columns = MasonryColumns.fill(500, maxWidth: 240, spacing: 8);

      expect(columns.count, 3);
      expect(columns.width, closeTo((500 - 16) / 3, 0.001));
      expect(columns.startOf(2), closeTo(2 * (columns.width + 8), 0.001));
    });

    test('one column at least', () {
      expect(MasonryColumns.fill(0, maxWidth: 240, spacing: 8).count, 1);
    });
  });

  test('puts each item in the shortest column, the first of equal ones', () {
    final placement = measured([100, 50, 30, 40]);

    expect(placement.spotOf(0), (column: 0, top: 0.0, extent: 100.0));
    expect(placement.spotOf(1), (column: 1, top: 0.0, extent: 50.0));
    expect(placement.spotOf(2), (column: 1, top: 60.0, extent: 30.0));
    expect(placement.spotOf(3), (column: 1, top: 100.0, extent: 40.0));
    expect(placement.extent, 140);
  });

  test('an item that grows moves only the items below it in its column, '
      'once their columns are kept', () {
    final placement = measured([100, 50, 30, 40]);
    for (final index in [0, 1, 2, 3]) {
      placement.keepColumn(index);
    }

    expect(placement.measure(1, 200), isTrue);

    expect(placement.spotOf(0), (column: 0, top: 0.0, extent: 100.0));
    expect(placement.spotOf(2), (column: 1, top: 210.0, extent: 30.0));
    expect(placement.spotOf(3), (column: 1, top: 250.0, extent: 40.0));
  });

  test('without kept columns, the items after a grown one go to the '
      'shortest column again', () {
    final placement = measured([100, 50, 30, 40])
      ..keepColumn(2)
      ..releaseColumns()
      ..measure(1, 200);

    expect(placement.spotOf(2).column, 0);
  });

  test('a height told again moves nothing', () {
    final placement = measured([100, 50]);

    expect(placement.measure(0, 100), isFalse);
  });

  test('items not measured count as tall as the measured ones on average', () {
    final placement = MasonryPlacement(columns: 1, gap: 10)
      ..count = 4
      ..measure(0, 100)
      ..measure(1, 50);

    expect(placement.spotOf(3), (column: 0, top: 255.0, extent: 75.0));
  });

  group('items between', () {
    test('with nothing measured, only the first item', () {
      final placement = MasonryPlacement(columns: 2, gap: 10)..count = 100;

      expect(placement.itemsBetween(5000, 6000), (first: 0, last: 0));
    });

    test('the items reaching into the stretch, and all between them', () {
      final placement = measured([100, 50, 30, 40, 300, 20]);

      expect(placement.itemsBetween(0, 55), (first: 0, last: 1));
      expect(placement.itemsBetween(95, 105), (first: 0, last: 3));
      expect(placement.itemsBetween(420, 500), isNull);
    });

    test('none with no items', () {
      expect(
        MasonryPlacement(columns: 2, gap: 10).itemsBetween(0, 100),
        isNull,
      );
    });
  });

  test('fewer items drop what was known of the others', () {
    final placement = measured([100, 50, 30])..count = 2;

    expect(placement.extent, 100);
    placement.count = 3;
    expect(placement.spotOf(2).extent, 75);
  });
}
