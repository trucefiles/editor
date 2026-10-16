import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Refreshes when the user pulls [child] down past its top, by touch
/// only: scrolling up with a mouse wheel or trackpad on desktop just
/// scrolls. Only vertical scrolling pulls, so a view that scrolls
/// sideways inside (wide tables) never does.
class PullToRefresh extends StatelessWidget {
  const PullToRefresh({
    required this.onRefresh,
    required this.child,
    super.key,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  /// Pointers that pull: fingers and pens on a touchscreen.
  static const _pulling = {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };

  /// A pull starts with a scroll that a drag started; only such a start
  /// matters, the rest of the scroll follows it.
  static bool _pulls(ScrollNotification notification) =>
      notification.metrics.axis == Axis.vertical &&
      switch (notification) {
        ScrollStartNotification(:final dragDetails?) => _pulling.contains(
          dragDetails.kind,
        ),
        _ => true,
      };

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    notificationPredicate: _pulls,
    child: child,
  );
}
