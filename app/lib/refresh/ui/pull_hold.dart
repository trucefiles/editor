import 'dart:math';

import 'package:flutter/widgets.dart';

/// Holds the content at its top while a pull to refresh is taken back:
/// moving the finger up first shrinks the pull, as far as it went, and
/// only then scrolls. Follows the scrolls that may pull.
final class PullHold {
  bool _dragging = false;
  double _pulled = 0;

  /// Whether a move towards the content below would now take a pull back.
  bool get holding => _pulled > 0;

  /// Follows [notification] of a scroll that may pull: a drag pulls as far
  /// as it moves the content past its top.
  void onScroll(ScrollNotification notification) {
    switch (notification) {
      case ScrollStartNotification(dragDetails: _?):
        _dragging = true;
        _pulled = 0;
      case OverscrollNotification(:final overscroll) when _dragging:
        _pulled = max(0, _pulled - overscroll);
      case ScrollEndNotification():
        _dragging = false;
        _pulled = 0;
      default:
    }
  }

  /// How much of a move by [delta] towards the content below takes the
  /// pull back instead of scrolling.
  double held(double delta) => min(delta, _pulled);
}

/// Scroll physics that leave to [hold] the moves taking a pull back.
class PullHoldPhysics extends ScrollPhysics {
  const PullHoldPhysics(this.hold, {super.parent});

  final PullHold hold;

  @override
  PullHoldPhysics applyTo(ScrollPhysics? ancestor) =>
      PullHoldPhysics(hold, parent: buildParent(ancestor));

  /// At the top, the held part of a move is reported as overscroll, which
  /// the refresh indicator takes as the pull shrinking.
  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final delta = value - position.pixels;
    final atTop = position.pixels <= position.minScrollExtent;
    if (position.axis != Axis.vertical || delta <= 0 || !atTop) {
      return super.applyBoundaryConditions(position, value);
    }
    final held = hold.held(delta);
    if (held == delta) return held;
    return held + super.applyBoundaryConditions(position, value - held);
  }
}
