import 'package:flutter/widgets.dart';

/// Scrolls the document while a dragged copy reaches past its top or
/// bottom edge, with Flutter's own edge scroller (as reorderable lists
/// do), so an item can go anywhere in one drag, also with one hand.
final class DragEdgeScroll {
  DragEdgeScroll({required this.onScrolled});

  /// The document scrolled a step: what is under the copy changed.
  final VoidCallback onScrolled;

  EdgeDraggingAutoScroller? _scroller;

  /// How fast it scrolls per pixel the copy is past the edge; that of
  /// reorderable lists.
  static const _speed = 50.0;

  /// The copy is at [copy] on screen, over the scrollable around
  /// [inside], if any.
  void at(Rect copy, BuildContext inside) {
    final scrollable = Scrollable.maybeOf(inside);
    if (scrollable == null) return stop();
    final scroller = switch (_scroller) {
      final scroller? when scroller.scrollable == scrollable => scroller,
      _ => _newScroller(scrollable),
    };
    scroller.startAutoScrollIfNecessary(copy);
  }

  EdgeDraggingAutoScroller _newScroller(ScrollableState scrollable) {
    stop();
    return _scroller = EdgeDraggingAutoScroller(
      scrollable,
      onScrollViewScrolled: onScrolled,
      velocityScalar: _speed,
    );
  }

  /// The drag is over, or off the document: no more scrolling.
  void stop() {
    _scroller?.stopAutoScroll();
    _scroller = null;
  }
}
