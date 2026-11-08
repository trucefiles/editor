import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../touch/touch.dart';
import '../wheel/wheel_step.dart';

/// One row of [chips], 8 apart, that scrolls sideways when it doesn't fit:
/// by a swipe, and with a mouse also by the plain wheel. In the desktop
/// look (not [usesTouch]) a small arrow lies over each edge while chips
/// are hidden on that side; a press scrolls about the row's width.
class ChipRow extends StatefulWidget {
  const ChipRow({
    required this.chips,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final List<Widget> chips;

  /// Space around the chips, inside the scrolling row.
  final EdgeInsets padding;

  @override
  State<ChipRow> createState() => _ChipRowState();
}

class _ChipRowState extends State<ChipRow> {
  final _scroll = ScrollController();

  /// Whether chips are hidden before and after what shows.
  final _hidden = ValueNotifier<({bool before, bool after})>((
    before: false,
    after: false,
  ));

  @override
  void dispose() {
    _scroll.dispose();
    _hidden.dispose();
    super.dispose();
  }

  /// Keeps up with what is hidden as the row scrolls or changes size.
  bool _showHidden(Notification notification) {
    if (notification
        case ScrollNotification(:final metrics) ||
            ScrollMetricsNotification(:final metrics)) {
      _hidden.value = (
        before: metrics.extentBefore > 0,
        after: metrics.extentAfter > 0,
      );
    }
    return false;
  }

  /// Turns a plain mouse wheel step into a sideways scroll; Flutter
  /// scrolls a sideways row only by a sideways step. Claimed only when
  /// the row moves, so the page scrolls on where the row can't.
  void _onSignal(PointerSignalEvent event) {
    if (mouseWheelStep(context, event) case Offset(dx: 0, :final dy)
        when dy != 0 && _scroll.hasClients) {
      final position = _scroll.position;
      final to = (position.pixels + dy).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (to == position.pixels) return;
      GestureBinding.instance.pointerSignalResolver.register(
        event,
        (_) => position.pointerScroll(dy),
      );
    }
  }

  /// Scrolls about the row's width towards its end ([direction] 1) or
  /// its start (-1).
  void _page(int direction) {
    final position = _scroll.position;
    final to = (position.pixels + direction * position.viewportDimension * 0.8)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    unawaited(
      _scroll.animateTo(
        to,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final row = Listener(
      onPointerSignal: _onSignal,
      child: NotificationListener(
        onNotification: _showHidden,
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: widget.padding,
          child: Row(spacing: 8, children: widget.chips),
        ),
      ),
    );
    if (usesTouch(Theme.of(context))) return row;
    return Stack(
      children: [
        row,
        ValueListenableBuilder(
          valueListenable: _hidden,
          builder: (context, hidden, _) => Positioned.fill(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hidden.before)
                  _EdgeArrow(start: true, onPressed: () => _page(-1)),
                const Spacer(),
                if (hidden.after)
                  _EdgeArrow(start: false, onPressed: () => _page(1)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A small arrow over the row's [start] or end edge, fading the chips
/// under it into the background; only the arrow takes taps, so a chip
/// under the fade still does.
class _EdgeArrow extends StatelessWidget {
  const _EdgeArrow({required this.start, required this.onPressed});

  final bool start;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).colorScheme.surface;
    final (outer, inner) = start
        ? (AlignmentDirectional.centerStart, AlignmentDirectional.centerEnd)
        : (AlignmentDirectional.centerEnd, AlignmentDirectional.centerStart);
    // A pointer aid only: keys and screen readers reach every chip.
    return ExcludeFocus(
      child: ExcludeSemantics(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: inner,
                      end: outer,
                      colors: [background.withValues(alpha: 0), background],
                      stops: const [0, 0.5],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: start ? 0 : 16,
                end: start ? 16 : 0,
              ),
              child: Center(
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  icon: Icon(start ? Icons.chevron_left : Icons.chevron_right),
                  onPressed: onPressed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
