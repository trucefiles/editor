import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import 'line_drag.dart';

/// Where a dragged item goes: next to [item], below or above it; the
/// gap that opens there is [height] high, as the dragged row.
typedef LineGap = ({LineId item, bool below, double height});

/// A row and where it is on screen as without any gap, so a gap opening
/// never moves what decides where it opens.
typedef _Place = ({_LineDropTargetState row, double top, double bottom});

/// The one drop target for items dragged anywhere over [child], and the
/// one owner of where they go: the row, a [LineDropTarget] in [child],
/// nearest to the dragged copy's middle, above or below its middle.
/// Exactly one gap is open, there.
class LineDropZone extends StatefulWidget {
  const LineDropZone({required this.child, super.key});

  final Widget child;

  @override
  State<LineDropZone> createState() => _LineDropZoneState();
}

class _LineDropZoneState extends State<LineDropZone> {
  final _rows = <_LineDropTargetState>{};

  /// Where the item dragged over [LineDropZone.child] would go; `null`
  /// while none is, or while it is over its own row.
  final _gap = ValueNotifier<LineGap?>(null);

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
    _gap.value = null;
    final drag = details.data;
    if (drag.at(details.offset) case final copy?) {
      if (_placeAt(copy.middle) case final place?) {
        final row = place.row.widget;
        row.onDrop(
          drag.item,
          below: _isBelow(place, copy.middle),
          levels: (copy.shift / row.step).truncate(),
        );
      }
    }
  }

  @override
  void dispose() {
    _gap.dispose();
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
/// opens there, as large as the dragged row. A row's own copy, shifted
/// sideways by whole [step]s, goes that many levels deeper or shallower.
class LineDropTarget extends StatefulWidget {
  const LineDropTarget({
    required this.item,
    required this.step,
    required this.onDrop,
    required this.child,
    super.key,
  });

  final LineId item;

  /// Width of one level.
  final double step;

  /// The dropped item, whether it goes below, and by how many
  /// levels it was shifted deeper (shallower if negative).
  final void Function(LineId item, {required bool below, required int levels})
  onDrop;
  final Widget child;

  @override
  State<LineDropTarget> createState() => _LineDropTargetState();
}

class _LineDropTargetState extends State<LineDropTarget> {
  final _content = GlobalKey();
  late final _LineDropZoneState _zone;

  @override
  void initState() {
    super.initState();
    _zone =
        context.findAncestorStateOfType<_LineDropZoneState>() ??
        (throw FlutterError('A LineDropTarget needs a LineDropZone above it'));
    _zone._rows.add(this);
  }

  @override
  void dispose() {
    _zone._rows.remove(this);
    super.dispose();
  }

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
    final content = _content.currentContext?.findRenderObject();
    final whole = context.findRenderObject();
    if (content is! RenderBox || whole is! RenderBox || !whole.hasSize) {
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
