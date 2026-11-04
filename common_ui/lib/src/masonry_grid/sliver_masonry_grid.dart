import 'package:flutter/widgets.dart';

import 'render_sliver_masonry_grid.dart';

/// A masonry grid in a vertical scroll view: [itemCount] items, each built
/// by [itemBuilder] and as tall as its content, in columns at most
/// [maxColumnWidth] wide, [spacing] apart both ways. Builds only the items
/// near the screen.
///
/// An item whose size is not final yet says so with a [MasonryItem]; the
/// grid shows it, and the items after it, once it is ready.
class SliverMasonryGrid extends SliverMultiBoxAdaptorWidget {
  SliverMasonryGrid({
    required int itemCount,
    required NullableIndexedWidgetBuilder itemBuilder,
    required this.maxColumnWidth,
    this.spacing = 0,
    super.key,
  }) : super(
         // No wrappers around the items, so a [MasonryItem] reaches the
         // grid. Items that need a repaint boundary bring their own.
         delegate: SliverChildBuilderDelegate(
           itemBuilder,
           childCount: itemCount,
           addAutomaticKeepAlives: false,
           addRepaintBoundaries: false,
           addSemanticIndexes: false,
         ),
       );

  final double maxColumnWidth;
  final double spacing;

  @override
  RenderSliverMasonryGrid createRenderObject(BuildContext context) =>
      RenderSliverMasonryGrid(
        childManager: context as SliverMultiBoxAdaptorElement,
        maxColumnWidth: maxColumnWidth,
        spacing: spacing,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverMasonryGrid renderObject,
  ) => renderObject
    ..maxColumnWidth = maxColumnWidth
    ..spacing = spacing
    ..itemsChanged();
}

/// An item of a [SliverMasonryGrid] that tells whether its size is final:
/// while [ready] is false, the grid holds it and the items after it back.
/// Must be the outermost widget of the item.
class MasonryItem extends ParentDataWidget<MasonryParentData> {
  const MasonryItem({required this.ready, required super.child, super.key});

  final bool ready;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as MasonryParentData;
    if (data.ready == ready) return;
    data.ready = ready;
    renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => SliverMasonryGrid;
}
