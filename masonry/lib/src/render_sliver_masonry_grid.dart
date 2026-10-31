import 'dart:math';

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/rendering.dart';

import 'masonry_columns.dart';
import 'masonry_placement.dart';

/// What a [RenderSliverMasonryGrid] keeps on each of its items.
class MasonryParentData extends SliverMultiBoxAdaptorParentData {
  /// Where the item starts across the grid.
  double crossAxisOffset = 0;

  /// The item's size is final: it may be shown.
  bool ready = true;

  /// The item was shown; it stays shown.
  bool shown = false;
}

/// Lays out a masonry grid in a vertical scroll view, building only the
/// items near the screen (Flutter has no masonry grid; this follows its
/// own `RenderSliverGrid` and `RenderSliverList`).
///
/// Shows items in order, each once it is ready and every item built before
/// it was shown, so items appear at their final size. When items above the
/// screen change size, the scroll offset follows, so what is on screen
/// stays in place.
class RenderSliverMasonryGrid extends RenderSliverMultiBoxAdaptor {
  RenderSliverMasonryGrid({
    required super.childManager,
    required this._maxColumnWidth,
    required this._spacing,
  });

  double _maxColumnWidth;
  double _spacing;
  MasonryColumns? _columns;
  MasonryPlacement? _placement;

  set maxColumnWidth(double value) {
    if (value == _maxColumnWidth) return;
    _maxColumnWidth = value;
    markNeedsLayout();
  }

  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  /// The items may have changed: each goes to the shortest column again.
  void itemsChanged() {
    _placement?.releaseColumns();
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! MasonryParentData) {
      child.parentData = MasonryParentData();
    }
  }

  @override
  double childCrossAxisPosition(RenderBox child) =>
      _dataOf(child).crossAxisOffset;

  @override
  bool paintsChild(RenderBox child) =>
      super.paintsChild(child) && _dataOf(child).shown;

  @override
  void performLayout() {
    assert(
      constraints.axisDirection == AxisDirection.down,
      'A masonry grid scrolls down only.',
    );
    childManager
      ..didStartLayout()
      ..setDidUnderflow(false);
    final columns = MasonryColumns.fill(
      constraints.crossAxisExtent,
      maxWidth: _maxColumnWidth,
      spacing: _spacing,
    );
    final placement = _placementFor(columns)..count = childManager.childCount;
    final anchor = _anchor();
    final start = constraints.scrollOffset + constraints.cacheOrigin;
    final end = start + constraints.remainingCacheExtent;
    final box = constraints.asBoxConstraints(crossAxisExtent: columns.width);

    var range = placement.itemsBetween(start, end);
    while (range != null && _layOut(range, box, placement)) {
      range = placement.itemsBetween(start, end);
    }
    if (range == null) collectGarbage(childCount, 0);

    _show(placement);
    _position(placement, columns);
    final extent = placement.extent;
    final correction = _correction(anchor, placement);
    geometry = correction != 0
        ? SliverGeometry(scrollOffsetCorrection: correction)
        : SliverGeometry(
            scrollExtent: extent,
            paintExtent: calculatePaintOffset(constraints, from: 0, to: extent),
            cacheExtent: calculateCacheOffset(constraints, from: 0, to: extent),
            maxPaintExtent: extent,
            hasVisualOverflow:
                constraints.scrollOffset > 0 ||
                extent > constraints.remainingPaintExtent,
          );
    childManager.didFinishLayout();
  }

  MasonryPlacement _placementFor(MasonryColumns columns) {
    if (columns != _columns || _placement == null) {
      _columns = columns;
      _placement = MasonryPlacement(columns: columns.count, gap: _spacing);
    }
    return _placement!;
  }

  /// Builds and lays out the items in [range], drops the others and tells
  /// [placement] their heights; true if that moved any item.
  bool _layOut(
    MasonryRange range,
    BoxConstraints box,
    MasonryPlacement placement,
  ) {
    if (firstChild != null) {
      collectGarbage(
        calculateLeadingGarbage(firstIndex: range.first),
        calculateTrailingGarbage(lastIndex: range.last),
      );
    }
    if (firstChild == null && !addInitialChild(index: range.first)) {
      return false;
    }
    while (indexOf(firstChild!) > range.first) {
      if (insertAndLayoutLeadingChild(box, parentUsesSize: true) == null) {
        break;
      }
    }
    while (indexOf(lastChild!) < range.last) {
      if (insertAndLayoutChild(box, after: lastChild, parentUsesSize: true) ==
          null) {
        break;
      }
    }
    var moved = false;
    for (final child in _children) {
      child.layout(box, parentUsesSize: true);
      moved = placement.measure(indexOf(child), child.size.height) || moved;
    }
    return moved;
  }

  /// Shows each built item that is ready, in order, up to the first one
  /// that is not; an item shown keeps its column.
  void _show(MasonryPlacement placement) {
    var open = true;
    for (final child in _children) {
      final data = _dataOf(child);
      data.shown = data.shown || (open && data.ready);
      open = open && data.shown;
      if (data.shown) placement.keepColumn(data.index!);
    }
  }

  void _position(MasonryPlacement placement, MasonryColumns columns) {
    for (final child in _children) {
      final data = _dataOf(child);
      final spot = placement.spotOf(data.index!);
      data
        ..layoutOffset = spot.top
        ..crossAxisOffset = columns.startOf(spot.column);
    }
  }

  /// The first item shown at the top of the screen, and where it was.
  ({int index, double top})? _anchor() {
    final top = constraints.scrollOffset;
    final bottom = top + constraints.remainingPaintExtent;
    return _children
        .where((child) => _dataOf(child).shown && child.hasSize)
        .map(
          (child) => (
            index: indexOf(child),
            top: childScrollOffset(child)!,
            bottom: childScrollOffset(child)! + child.size.height,
          ),
        )
        .where((item) => item.bottom > top && item.top < bottom)
        .map((item) => (index: item.index, top: item.top))
        .firstOrNull;
  }

  /// How far to scroll so that [anchor] stays where it was on screen.
  double _correction(
    ({int index, double top})? anchor,
    MasonryPlacement placement,
  ) {
    if (anchor == null ||
        anchor.index >= placement.count ||
        constraints.scrollOffset == 0) {
      return 0;
    }
    final moved = placement.spotOf(anchor.index).top - anchor.top;
    return moved.abs() < precisionErrorTolerance
        ? 0
        : max(moved, -constraints.scrollOffset);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in _children.where(paintsChild)) {
      final main = childMainAxisPosition(child);
      if (main < constraints.remainingPaintExtent &&
          main + child.size.height > 0) {
        context.paintChild(
          child,
          offset + Offset(childCrossAxisPosition(child), main),
        );
      }
    }
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    final boxResult = BoxHitTestResult.wrap(result);
    return _children
        .toList()
        .reversed
        .where(paintsChild)
        .any(
          (child) => hitTestBoxChild(
            boxResult,
            child,
            mainAxisPosition: mainAxisPosition,
            crossAxisPosition: crossAxisPosition,
          ),
        );
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) =>
      _children.where(paintsChild).forEach(visitor);

  Iterable<RenderBox> get _children sync* {
    for (var child = firstChild; child != null; child = childAfter(child)) {
      yield child;
    }
  }

  static MasonryParentData _dataOf(RenderBox child) =>
      child.parentData! as MasonryParentData;
}
