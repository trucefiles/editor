import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pull_hold.dart';

/// Refreshes when the user pulls [child] down past its top, by touch
/// only: scrolling up with a mouse wheel or trackpad on desktop just
/// scrolls. Only the vertical scrolling of [child]'s own scroll view
/// pulls, never a view that scrolls inside it (wide tables, text that
/// scrolls in itself), which scrolls as it would anywhere else. Taking a
/// pull back moves only the indicator, and a refresh shows for at least
/// [_minShown], so it is told apart from a pull let go too early. A
/// Refresh button runs the same refresh, shown the same way, through
/// [PullToRefreshState.refresh].
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
  State<PullToRefresh> createState() => PullToRefreshState();
}

class PullToRefreshState extends State<PullToRefresh> {
  final _hold = PullHold();
  final _indicator = GlobalKey<RefreshIndicatorState>();

  late ScrollBehavior _scrolling;

  /// Refreshes as a pull does, with its indicator; done once the refresh
  /// is.
  Future<void> refresh() => _indicator.currentState!.show();

  /// Pointers that pull: fingers and pens on a touchscreen.
  static const _pulling = {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };

  /// A pull starts with a scroll of the page, not of a view inside it,
  /// that a drag started; only such a start matters, the rest of the
  /// scroll follows it.
  static bool _pulls(ScrollNotification notification) =>
      notification.depth == 0 &&
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
    _scrolling = _PullBehavior(
      this,
      ambient,
      // Pulls down even when the content fits, e.g. a short note in a
      // scroll view the child builds itself.
      pulling: PullHoldPhysics(
        _hold,
        parent: AlwaysScrollableScrollPhysics(
          parent: ambient.getScrollPhysics(context),
        ),
      ),
    );
  }

  /// Whether the scroll view of [scrollable] is [PullToRefresh.child]'s
  /// own: in no other scroll view inside it.
  bool _owns(BuildContext scrollable) =>
      scrollable
          .findAncestorStateOfType<ScrollableState>()
          ?.context
          .findAncestorStateOfType<PullToRefreshState>() !=
      this;

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
    key: _indicator,
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

/// [ambient] with the [pulling] physics for the child's own scroll view
/// of [state] (see [PullToRefreshState._owns]); views that scroll inside
/// it keep the ambient physics.
final class _PullBehavior extends ScrollBehavior {
  const _PullBehavior(this.state, this.ambient, {required this.pulling});

  final PullToRefreshState state;
  final ScrollBehavior ambient;
  final ScrollPhysics pulling;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      state._owns(context) ? pulling : ambient.getScrollPhysics(context);

  @override
  Set<PointerDeviceKind> get dragDevices => ambient.dragDevices;

  @override
  Set<LogicalKeyboardKey> get pointerAxisModifiers =>
      ambient.pointerAxisModifiers;

  @override
  MultitouchDragStrategy getMultitouchDragStrategy(BuildContext context) =>
      ambient.getMultitouchDragStrategy(context);

  @override
  TargetPlatform getPlatform(BuildContext context) =>
      ambient.getPlatform(context);

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => ambient.buildScrollbar(context, child, details);

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => ambient.buildOverscrollIndicator(context, child, details);

  @override
  GestureVelocityTrackerBuilder velocityTrackerBuilder(BuildContext context) =>
      ambient.velocityTrackerBuilder(context);

  @override
  ScrollViewKeyboardDismissBehavior getKeyboardDismissBehavior(
    BuildContext context,
  ) => ambient.getKeyboardDismissBehavior(context);

  @override
  bool shouldNotify(_PullBehavior oldDelegate) =>
      oldDelegate.ambient != ambient ||
      oldDelegate.pulling != pulling ||
      ambient.shouldNotify(oldDelegate.ambient);
}
