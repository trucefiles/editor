import 'dart:math';

import 'package:collection/collection.dart';

/// Where one item of a masonry grid sits: its column, its top and its
/// height.
typedef MasonrySpot = ({int column, double top, double extent});

/// The items of a masonry grid from [first] to [last], both included.
typedef MasonryRange = ({int first, int last});

/// Places the [count] items of a masonry grid in [columns] columns, in
/// order: each goes to the shortest column at its turn (the first of equal
/// ones), [gap] below the item before it there.
///
/// An item whose column is kept stays in that column, so an item already
/// shown never moves to another column when items before it change size.
/// Items not measured yet count as tall as the measured ones on average.
final class MasonryPlacement {
  MasonryPlacement({required this.columns, required this.gap})
    : assert(columns > 0);

  final int columns;

  /// Space between two items in a column.
  final double gap;

  int _count = 0;
  final _extents = <int, double>{};
  final _keptColumns = <int, int>{};

  /// The spots of all items, derived from the facts above; null when one
  /// of them changed since.
  List<MasonrySpot>? _spots;

  int get count => _count;

  /// Sets how many items there are; facts on items past the end go.
  set count(int value) {
    if (value == _count) return;
    _count = value;
    _extents.removeWhere((index, _) => index >= value);
    _keptColumns.removeWhere((index, _) => index >= value);
    _spots = null;
  }

  /// Tells the height item [index] has; true if that moves any item.
  bool measure(int index, double extent) {
    if (_extents[index] == extent) return false;
    _extents[index] = extent;
    _spots = null;
    return true;
  }

  /// Keeps item [index] in the column it has now.
  void keepColumn(int index) => _keptColumns[index] ??= spotOf(index).column;

  /// Lets every item go to the shortest column again: the items changed.
  void releaseColumns() {
    if (_keptColumns.isEmpty) return;
    _keptColumns.clear();
    _spots = null;
  }

  MasonrySpot spotOf(int index) => _placed[index];

  /// The height of the whole grid.
  double get extent =>
      _placed.fold(0, (bottom, spot) => max(bottom, spot.top + spot.extent));

  /// The items that reach into the stretch from [start] to [end], and all
  /// items between them; null if none does. With nothing measured yet,
  /// only the first item: its height is the first estimate.
  MasonryRange? itemsBetween(double start, double end) {
    if (_count == 0) return null;
    if (_extents.isEmpty) return (first: 0, last: 0);
    bool reaches(MasonrySpot spot) =>
        spot.top < end && spot.top + spot.extent > start;
    final first = _placed.indexWhere(reaches);
    return first < 0
        ? null
        : (first: first, last: _placed.lastIndexWhere(reaches));
  }

  List<MasonrySpot> get _placed => _spots ??= _place();

  /// Places every item in order, in one pass.
  List<MasonrySpot> _place() {
    final estimate = _extents.isEmpty ? 0.0 : _extents.values.average;
    // Where the next item in each column would start.
    final tops = List.filled(columns, 0.0);
    final spots = <MasonrySpot>[];
    for (var index = 0; index < _count; index++) {
      final column = _keptColumns[index] ?? _shortest(tops);
      final extent = _extents[index] ?? estimate;
      spots.add((column: column, top: tops[column], extent: extent));
      tops[column] += extent + gap;
    }
    return spots;
  }

  static int _shortest(List<double> tops) =>
      tops.indexed.reduce((a, b) => b.$2 < a.$2 ? b : a).$1;
}
