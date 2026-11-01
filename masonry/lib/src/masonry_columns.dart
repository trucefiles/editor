import 'dart:math';

import 'package:flutter/foundation.dart';

/// The columns of a masonry grid: as many as fit at most [maxWidth] each,
/// all equally wide, with [spacing] between them.
@immutable
final class MasonryColumns {
  /// The columns that fill [width].
  factory MasonryColumns.fill(
    double width, {
    required double maxWidth,
    required double spacing,
  }) {
    final count = max(1, (width / (maxWidth + spacing)).ceil());
    return MasonryColumns._(
      count,
      width: max(0, (width - spacing * (count - 1)) / count),
      spacing: spacing,
    );
  }

  const MasonryColumns._(
    this.count, {
    required this.width,
    required this.spacing,
  });

  final int count;

  /// The width of each column.
  final double width;

  final double spacing;

  /// Where [column] starts, from the grid's start edge.
  double startOf(int column) => column * (width + spacing);

  @override
  bool operator ==(Object other) =>
      other is MasonryColumns &&
      other.count == count &&
      other.width == width &&
      other.spacing == spacing;

  @override
  int get hashCode => Object.hash(count, width, spacing);
}
