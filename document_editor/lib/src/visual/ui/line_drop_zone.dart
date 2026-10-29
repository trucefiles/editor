import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:truce_markdown/truce_markdown.dart' show NodeId;

import 'line_drag.dart';

/// Where a dragged item goes: next to [item], below or above it; the
/// gap that opens there is [height] high, as the dragged row.
typedef LineGap = ({NodeId item, bool below, double height});

/// A row and where it is on screen as without any gap, so a gap opening
/// never moves what decides where it opens.
typedef _Place = ({_LineDropTargetState row, double top, double bottom});

/// The one drop target for items dragged anywhere over [child], and the
/// one owner of a drag from lift to settle: where the item goes (the row,
/// a [LineDropTarget] in [child], nearest to the dragged copy's middle,
/// above or below its middle), the one gap open there, and the glide of
/// the copy on release, into the gap or, for a drag dropped nowhere,
/// back to its row.
class LineDropZone extends StatefulWidget {
  const LineDropZone({
    required this.step,
    required this.onLift,
    required this.onDrop,
    required this.onSettled,
    required this.child,
    super.key,
  });

  /// Width of one level.
  final double step;

  /// A drag started.
  final ValueChanged<LineDrag> onLift;

  /// [drag]'s item dropped next to [target], [below] it or above; on its
  /// own row, shifted by [levels] deeper (shallower if negative).
  final void Function(
    LineDrag drag, {
    required NodeId target,
    required bool below,
    required int levels,
  })
  onDrop;

  /// The drag is over, its copy settled.
  final VoidCallback onSettled;

  final Widget child;

  /// The zone around [context].
  static LineDropZoneState of(BuildContext context) =>
      context.findAncestorStateOfType<LineDropZoneState>() ??
      (throw FlutterError('A drag handle or row needs a LineDropZone above'));

  @override
  State<LineDropZone> createState() => LineDropZoneState();
}

class LineDropZoneState extends State<LineDropZone> {
  final _rows = <_LineDropTargetState>{};

  /// Where the item dragged over [LineDropZone.child] would go; `null`
  /// while none is, or while it is over its own row.
  final _gap = ValueNotifier<LineGap?>(null);

  final _lifted = ValueNotifier<NodeId?>(null);

  /// The copy gliding into place, if any.
  OverlayEntry? _glide;

  static const _glideTime = Duration(milliseconds: 150);

  /// The item being dragged, from lift until its copy settled.
  ValueNotifier<NodeId?> get lifted => _lifted;

  /// [drag] started.
  void lift(LineDrag drag) {
    _lifted.value = drag.item;
    widget.onLift(drag);
  }

  /// [drag] dropped nowhere, its copy at [offset]: it glides back.
  void cancel(LineDrag drag, Offset offset) {
    _gap.value = null;
    _glideTo(drag, from: offset, to: _rowOrigin(drag), then: () {});
  }

  /// The rows top to bottom, measured now, each less the gaps open above
  /// it: rows come and go, scroll and zoom during a drag.
  List<_Place> _places() {
    final measured = [for (final row in _rows) ?row._measure()]
        .sortedBy<num>((row) => row.top);
    final places = <_Place>[];
    var gapsAbove = 0.0;
    for (final (:row, :top, :height, :gapTop, :gaps) in measured) {
      final shown = top - gapsAbove - gapTop;
      places.add((row: row, top: shown, bottom: shown + height));
      gapsAbove += gaps;
    }
    return places;
  }

  /// The row nearest to the copy's middle at [middle], if any.
  _Place? _placeAt(double middle) => minBy(
    _places(),
    (place) => middle < place.top
        ? place.top - middle
        : middle > place.bottom
        ? middle - place.bottom
        : 0.0,
  );

  static bool _isBelow(_Place place, double middle) =>
      middle > (place.top + place.bottom) / 2;

  void _hover(DragTargetDetails<LineDrag> details) {
    final drag = details.data;
    _gap.value = switch (drag.at(details.offset)) {
      final copy? => switch (_placeAt(copy.middle)) {
        final place? when place.row.widget.item != drag.item => (
          item: place.row.widget.item,
          below: _isBelow(place, copy.middle),
          height: copy.height,
        ),
        _ => null,
      },
      null => null,
    };
  }

  void _drop(DragTargetDetails<LineDrag> details) {
    final drag = details.data;
    final copy = drag.at(details.offset);
    final place = copy == null ? null : _placeAt(copy.middle);
    if (copy == null || place == null) {
      return _glideTo(
        drag,
        from: details.offset,
        to: _rowOrigin(drag),
        then: () {},
      );
    }
    final target = place.row.widget.item;
    final below = _isBelow(place, copy.middle);
    _glideTo(
      drag,
      from: details.offset,
      to: target == drag.item
          ? _rowOrigin(drag)
          : _gapOrigin(drag, place.row, below: below, height: copy.height),
      then: () => widget.onDrop(
        drag,
        target: target,
        below: below,
        levels: (copy.shift / widget.step).truncate(),
      ),
    );
  }

  /// Where [drag]'s row is on screen; `null` once it is gone.
  Offset? _rowOrigin(LineDrag drag) => drag.rowBox?.localToGlobal(Offset.zero);

  /// Where the gap open next to [row] is on screen, at the dragged row's
  /// indent.
  Offset? _gapOrigin(
    LineDrag drag,
    _LineDropTargetState row, {
    required bool below,
    required double height,
  }) => switch ((_rowOrigin(drag), row._contentBox)) {
    (final origin?, final content?) => Offset(
      origin.dx,
      content.localToGlobal(Offset.zero).dy +
          (below ? content.size.height : -height),
    ),
    _ => null,
  };

  /// [drag]'s copy glides from [from] to [to], then [then] happens and
  /// the drag is settled; at once without [to], or when it is there
  /// already (a glide that goes nowhere never ends).
  void _glideTo(
    LineDrag drag, {
    required Offset from,
    required Offset? to,
    required VoidCallback then,
  }) {
    final overlay = Overlay.maybeOf(context);
    final box = overlay?.context.findRenderObject();
    if (to == null || to == from || overlay == null || box is! RenderBox) {
      return _settle(then);
    }
    final copy = drag.copy(
      textScaler: MediaQuery.textScalerOf(context),
      surface: Material.maybeOf(context)?.color,
    );
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => TweenAnimationBuilder<Offset>(
        tween: Tween(
          begin: box.globalToLocal(from),
          end: box.globalToLocal(to),
        ),
        duration: _glideTime,
        curve: Curves.easeOut,
        onEnd: () {
          entry.remove();
          _glide = null;
          _settle(then);
        },
        builder: (_, offset, child) =>
            Positioned(left: offset.dx, top: offset.dy, child: child!),
        child: IgnorePointer(child: copy),
      ),
    );
    _glide = entry;
    overlay.insert(entry);
  }

  /// The drop happens: [then], the gap closes, the row shows again.
  void _settle(VoidCallback then) {
    then();
    _gap.value = null;
    _lifted.value = null;
    widget.onSettled();
  }

  @override
  void dispose() {
    // Left mid-glide (e.g. the editor closed): the drop is not made.
    _glide?.remove();
    _gap.dispose();
    _lifted.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DragTarget<LineDrag>(
    onMove: _hover,
    onLeave: (_) => _gap.value = null,
    onAcceptWithDetails: _drop,
    builder: (_, _, _) => widget.child,
  );
}

/// The row of [item], [child], inside a [LineDropZone]: items dropped
/// next to it go above or below it, as the zone says; meanwhile a gap
/// opens there, as large as the dragged row.
class LineDropTarget extends StatefulWidget {
  const LineDropTarget({required this.item, required this.child, super.key});

  final NodeId item;
  final Widget child;

  @override
  State<LineDropTarget> createState() => _LineDropTargetState();
}

class _LineDropTargetState extends State<LineDropTarget> {
  final _content = GlobalKey();
  late final LineDropZoneState _zone;

  @override
  void initState() {
    super.initState();
    _zone = LineDropZone.of(context);
    _zone._rows.add(this);
  }

  @override
  void dispose() {
    _zone._rows.remove(this);
    super.dispose();
  }

  RenderBox? get _contentBox =>
      switch (_content.currentContext?.findRenderObject()) {
        final RenderBox box when box.hasSize => box,
        _ => null,
      };

  /// Where the row's content is on screen and how high, and the gap
  /// open above it and in all; `null` before it is laid out.
  ({
    _LineDropTargetState row,
    double top,
    double height,
    double gapTop,
    double gaps,
  })?
  _measure() {
    final content = _contentBox;
    final whole = context.findRenderObject();
    if (content == null || whole is! RenderBox || !whole.hasSize) {
      return null;
    }
    final top = content.localToGlobal(Offset.zero).dy;
    return (
      row: this,
      top: top,
      height: content.size.height,
      gapTop: top - whole.localToGlobal(Offset.zero).dy,
      gaps: whole.size.height - content.size.height,
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _zone._gap,
    builder: (context, gap, content) => AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      padding: switch (gap) {
        (:final item, :final below, :final height) when item == widget.item =>
          below
              ? EdgeInsets.only(bottom: height)
              : EdgeInsets.only(top: height),
        _ => EdgeInsets.zero,
      },
      child: content,
    ),
    child: KeyedSubtree(key: _content, child: widget.child),
  );
}
