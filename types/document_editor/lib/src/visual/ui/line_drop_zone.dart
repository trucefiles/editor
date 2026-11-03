import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:truce_markdown/truce_markdown.dart' show NodeId;

import 'line_drag.dart';
import 'line_drag_state.dart';

/// A row and where it is on screen as without any gap, so a gap opening
/// never moves what decides where it opens.
typedef _Place = ({_LineDropTargetState row, double top, double bottom});

/// Where a dragged item goes: next to [place]'s row, below it or above.
typedef _Target = ({_Place place, bool below});

/// The one drop target for items dragged anywhere over [child], and the
/// one owner of a drag from lift to settle: where the item goes (the row,
/// a [LineDropTarget] in [child], nearest to the dragged copy's middle,
/// above or below its middle), the one gap open there, and the glide of
/// the copy on release, into the gap while the row's old place closes,
/// onto its row shifted where it lands (a drop on its own row), or, for a
/// drag dropped nowhere, back to its row.
class LineDropZone extends StatefulWidget {
  const LineDropZone({
    required this.step,
    required this.staysInPlace,
    required this.onLift,
    required this.onDrop,
    required this.onSettled,
    required this.child,
    super.key,
  });

  /// Width of one level.
  final double step;

  /// Whether [item] dropped right next to [target], [below] it or above,
  /// stays where it is: no gap opens there, and a drop there is one on
  /// its own row.
  final bool Function(NodeId item, NodeId target, {required bool below})
  staysInPlace;

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

  final _drag = ValueNotifier<LineDragState>(const NoDrag());

  /// The copy gliding into place, if any.
  OverlayEntry? _glide;

  static const _glideTime = Duration(milliseconds: 150);

  /// Where the drag is, from lift until its copy settled.
  ValueListenable<LineDragState> get drag => _drag;

  /// [drag] started.
  void lift(LineDrag drag) {
    _drag.value = Lifted(drag.item);
    widget.onLift(drag);
  }

  /// [drag] dropped nowhere, its copy at [offset]: it glides back.
  void cancel(LineDrag drag, Offset offset) {
    _drag.value = Lifted(drag.item);
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

  /// Where [item]'s copy goes with its middle at [middle], among
  /// [places]: next to the row nearest to it, below it if past its
  /// middle; `null` where no row is, or where the item would stay where it
  /// is (its own row, or right next to it), so room opens only once the
  /// copy's middle passes a neighbor's middle.
  _Target? _targetAt(List<_Place> places, NodeId item, double middle) {
    final place = minBy(
      places,
      (place) => middle < place.top
          ? place.top - middle
          : middle > place.bottom
          ? middle - place.bottom
          : 0.0,
    );
    if (place == null) return null;
    final below = middle > (place.top + place.bottom) / 2;
    return widget.staysInPlace(item, place.row.widget.item, below: below)
        ? null
        : (place: place, below: below);
  }

  /// [item]'s own row among [places]; `null` once it is gone.
  static _Place? _ownPlace(List<_Place> places, NodeId item) =>
      places.firstWhereOrNull((place) => place.row.widget.item == item);

  /// The room the dragged row at [own] takes: its target's height, which
  /// holds the row's spacing too.
  double _roomOf(_Place own) => own.bottom - own.top;

  /// The gap for a drop at [target], as high as the dragged row at [own].
  LineGap _gapAt(_Target target, _Place own) => (
    item: target.place.row.widget.item,
    below: target.below,
    height: _roomOf(own),
  );

  void _hover(DragTargetDetails<LineDrag> details) {
    final drag = details.data;
    final places = _places();
    _drag.value = Lifted(
      drag.item,
      gap: switch ((drag.at(details.offset), _ownPlace(places, drag.item))) {
        (final copy?, final own?) => switch (_targetAt(
          places,
          drag.item,
          copy.middle,
        )) {
          final target? => _gapAt(target, own),
          null => null,
        },
        _ => null,
      },
    );
  }

  /// The drag left the zone: no gap stays open.
  void _leave() {
    if (_drag.value case Lifted(:final item)) _drag.value = Lifted(item);
  }

  void _drop(DragTargetDetails<LineDrag> details) {
    final drag = details.data;
    final places = _places();
    final copy = drag.at(details.offset);
    final own = _ownPlace(places, drag.item);
    if (copy == null || own == null) {
      return _glideTo(
        drag,
        from: details.offset,
        to: _rowOrigin(drag),
        then: () {},
      );
    }
    final levels = (copy.shift / widget.step).truncate();
    final target = _targetAt(places, drag.item, copy.middle);
    if (target == null) {
      // On its own row: the shift lands now, the row still faded, and the
      // copy glides to where the row then shows, however far it went.
      _drag.value = Lifted(drag.item);
      widget.onDrop(drag, target: drag.item, below: false, levels: levels);
      final glide = _glideFrom(drag, details.offset, then: () {});
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => glide(_rowOrigin(drag)),
      );
      return;
    }
    final (:place, :below) = target;
    _drag.value = Landing(drag.item, _gapAt(target, own));
    _glideTo(
      drag,
      from: details.offset,
      to: _landing(drag, own, place, below: below),
      then: () => widget.onDrop(
        drag,
        target: place.row.widget.item,
        below: below,
        levels: levels,
      ),
    );
  }

  /// Where [drag]'s row is on screen; `null` once it is gone.
  Offset? _rowOrigin(LineDrag drag) => drag.rowBox?.localToGlobal(Offset.zero);

  /// Where [drag]'s row lands next to [place], [below] it or above, from
  /// places measured without gaps: rows below its old place [own] move up
  /// by its room as that place closes. `null` once the row is gone.
  Offset? _landing(
    LineDrag drag,
    _Place own,
    _Place place, {
    required bool below,
  }) {
    final origin = _rowOrigin(drag);
    final content = own.row._contentBox;
    if (origin == null || content == null) return null;
    // The row may sit lower in its target than the target's top.
    final inset = origin.dy - content.localToGlobal(Offset.zero).dy;
    final top = below ? place.bottom : place.top;
    return Offset(
      origin.dx,
      top + inset - (own.top < place.top ? _roomOf(own) : 0),
    );
  }

  /// [drag]'s copy glides from [from] to [to], then [then] happens and
  /// the drag is settled.
  void _glideTo(
    LineDrag drag, {
    required Offset from,
    required Offset? to,
    required VoidCallback then,
  }) => _glideFrom(drag, from, then: then)(to);

  /// Shows [drag]'s copy at [from]; the function returned lets it glide
  /// to a place on screen, then [then] happens and the drag is settled:
  /// at once without a place, or when it is there already (a glide that
  /// goes nowhere never ends).
  void Function(Offset? to) _glideFrom(
    LineDrag drag,
    Offset from, {
    required VoidCallback then,
  }) {
    final overlay = Overlay.maybeOf(context);
    final box = overlay?.context.findRenderObject();
    if (overlay == null || box is! RenderBox) {
      _settle(then);
      return (_) {};
    }
    final start = box.globalToLocal(from);
    final end = ValueNotifier<Offset?>(null);
    late final OverlayEntry entry;
    void landed() {
      entry.remove();
      end.dispose();
      _glide = null;
      _settle(then);
    }

    entry = OverlayEntry(
      builder: (_) => ValueListenableBuilder(
        valueListenable: end,
        builder: (_, end, copy) => switch (end) {
          null => Positioned(left: start.dx, top: start.dy, child: copy!),
          final end => TweenAnimationBuilder<Offset>(
            tween: Tween(begin: start, end: end),
            duration: _glideTime,
            curve: Curves.easeOut,
            onEnd: landed,
            builder: (_, offset, copy) =>
                Positioned(left: offset.dx, top: offset.dy, child: copy!),
            child: copy,
          ),
        },
        child: IgnorePointer(
          child: drag.copy(
            textScaler: MediaQuery.textScalerOf(context),
            surface: Material.maybeOf(context)?.color,
          ),
        ),
      ),
    );
    _glide = entry;
    overlay.insert(entry);
    return (to) {
      // Left meanwhile (e.g. the editor closed): the glide went with it.
      if (!mounted || _glide != entry) return;
      switch (to) {
        case final to? when to != from:
          end.value = box.globalToLocal(to);
        case _:
          landed();
      }
    };
  }

  /// The drop happens: [then], and the drag is over, so the gap closes
  /// at once, in the frame the row shows in its new place.
  void _settle(VoidCallback then) {
    then();
    _drag.value = const NoDrag();
    widget.onSettled();
  }

  @override
  void dispose() {
    // Left mid-glide (e.g. the editor closed): the drop is not made.
    _glide?.remove();
    _drag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DragTarget<LineDrag>(
    onMove: _hover,
    onLeave: (_) => _leave(),
    onAcceptWithDetails: _drop,
    builder: (_, _, _) => widget.child,
  );
}

/// The row of [item], [child], inside a [LineDropZone]: items dropped
/// next to it go above or below it, as the zone says; meanwhile a gap
/// opens there, as large as the dragged row. Once [item] itself is
/// dropped elsewhere, its row closes while the copy glides.
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
    valueListenable: _zone._drag,
    builder: (context, drag, content) => AnimatedPadding(
      // Animated during a drag; once it is over, at once.
      duration: switch (drag) {
        NoDrag() => Duration.zero,
        _ => const Duration(milliseconds: 120),
      },
      padding: switch (drag.gap) {
        (:final item, :final below, :final height) when item == widget.item =>
          below
              ? EdgeInsets.only(bottom: height)
              : EdgeInsets.only(top: height),
        _ => EdgeInsets.zero,
      },
      child: switch (drag) {
        Landing(:final item) when item == widget.item => _Closing(
          child: content!,
        ),
        _ => content!,
      },
    ),
    child: KeyedSubtree(key: _content, child: widget.child),
  );
}

/// [child] shrinking to no height over the glide's time.
class _Closing extends StatelessWidget {
  const _Closing({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 1, end: 0),
    duration: LineDropZoneState._glideTime,
    curve: Curves.easeOut,
    builder: (_, height, child) => ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: height,
        child: child,
      ),
    ),
    child: child,
  );
}
