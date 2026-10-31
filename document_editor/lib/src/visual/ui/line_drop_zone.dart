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

/// Where a dragged item goes: next to [place]'s row, below it or above.
typedef _Target = ({_Place place, bool below});

/// The one drop target for items dragged anywhere over [child], and the
/// one owner of a drag from lift to settle: where the item goes (the row,
/// a [LineDropTarget] in [child], nearest to the dragged copy's middle,
/// above or below its middle), the one gap open there, and the glide of
/// the copy on release, into the gap while the row's old place closes,
/// or, for a drag dropped nowhere, back to its row.
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

  /// Where the item dragged over [LineDropZone.child] would go; `null`
  /// while none is, or while it is over its own row.
  final _gap = ValueNotifier<LineGap?>(null);

  final _lifted = ValueNotifier<NodeId?>(null);

  /// The item whose old place closes while its copy glides to the gap.
  final _leaving = ValueNotifier<NodeId?>(null);

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

  void _hover(DragTargetDetails<LineDrag> details) {
    final drag = details.data;
    final places = _places();
    _gap.value = switch ((
      drag.at(details.offset),
      _ownPlace(places, drag.item),
    )) {
      (final copy?, final own?) => switch (_targetAt(
        places,
        drag.item,
        copy.middle,
      )) {
        (:final place, :final below) => (
          item: place.row.widget.item,
          below: below,
          height: _roomOf(own),
        ),
        null => null,
      },
      _ => null,
    };
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
      return _glideTo(
        drag,
        from: details.offset,
        to: _rowOrigin(drag),
        then: () => widget.onDrop(
          drag,
          target: drag.item,
          below: false,
          levels: levels,
        ),
      );
    }
    final (:place, :below) = target;
    _leaving.value = drag.item;
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
    // No longer lifted first: the gap then closes at once, in the frame
    // the row shows in its new place, so no row moves twice.
    _lifted.value = null;
    _gap.value = null;
    _leaving.value = null;
    widget.onSettled();
  }

  @override
  void dispose() {
    // Left mid-glide (e.g. the editor closed): the drop is not made.
    _glide?.remove();
    _gap.dispose();
    _lifted.dispose();
    _leaving.dispose();
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
    valueListenable: _zone._gap,
    builder: (context, gap, content) => AnimatedPadding(
      // Animated while an item is lifted; once it settled, at once.
      duration: _zone._lifted.value == null
          ? Duration.zero
          : const Duration(milliseconds: 120),
      padding: switch (gap) {
        (:final item, :final below, :final height) when item == widget.item =>
          below
              ? EdgeInsets.only(bottom: height)
              : EdgeInsets.only(top: height),
        _ => EdgeInsets.zero,
      },
      child: ValueListenableBuilder(
        valueListenable: _zone._leaving,
        builder: (_, leaving, content) =>
            leaving == widget.item ? _Closing(child: content!) : content!,
        child: content,
      ),
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
