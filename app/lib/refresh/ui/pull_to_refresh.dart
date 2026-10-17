import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'pull_hold.dart';

/// Refreshes when the user pulls [child] down past its top, by touch
/// only: scrolling up with a mouse wheel or trackpad on desktop just
/// scrolls. Only vertical scrolling pulls, so a view that scrolls
/// sideways inside (wide tables) never does. Taking a pull back moves only
/// the indicator, and a refresh shows for at least [_minShown], so it is
/// told apart from a pull let go too early.
class PullToRefresh extends StatefulWidget {
  const PullToRefresh({
    required this.onRefresh,
    required this.child,
    super.key,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  /// How long a refresh shows at least.
  static const _minShown = Duration(milliseconds: 800);

  @override
  State<PullToRefresh> createState() => _PullToRefreshState();
}

class _PullToRefreshState extends State<PullToRefresh> {
  final _hold = PullHold();
  late ScrollBehavior _scrolling;

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

  /// Made once per ambient behavior: scroll views below rebuild their
  /// positions when their physics change.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ambient = ScrollConfiguration.of(context);
    _scrolling = ambient.copyWith(
      physics: PullHoldPhysics(
        _hold,
        parent: ambient.getScrollPhysics(context),
      ),
    );
  }

  Future<void> _refresh() async {
    await Future.wait([
      widget.onRefresh(),
      Future<void>.delayed(PullToRefresh._minShown),
    ]);
  }

  bool _onScroll(ScrollNotification notification) {
    if (_pulls(notification)) _hold.onScroll(notification);
    return false;
  }

  /// No overscroll effect at the bottom while a pull is taken back.
  bool _onOverscrollEffect(OverscrollIndicatorNotification notification) {
    if (_hold.holding && !notification.leading) {
      notification.disallowIndicator();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    notificationPredicate: _pulls,
    child: NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: NotificationListener<OverscrollIndicatorNotification>(
        onNotification: _onOverscrollEffect,
        child: ScrollConfiguration(behavior: _scrolling, child: widget.child),
      ),
    ),
  );
}
