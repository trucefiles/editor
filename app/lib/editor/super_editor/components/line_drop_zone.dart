import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import 'line_drag.dart';

/// Where a dragged item goes: next to [item], below or above it; the
/// gap that opens there is [height] high, as the dragged row.
typedef LineGap = ({LineId item, bool below, double height});

/// The one owner of where an item dragged over the [LineDropTarget]s in
/// [child] goes. It takes the dragged copy's middle against the rows'
/// places as they were when the drag began, before any gap opened, so a
/// gap opening never moves what decides it; exactly one gap is open.
/// A row and where it was, top to bottom on screen.
typedef _PlacedRow = ({_LineDropTargetState row, double top, double bottom});

class LineDropZone extends StatefulWidget {
  const LineDropZone({required this.child, super.key});

  final Widget child;

  static LineDropZoneState of(BuildContext context) =>
      context.findAncestorStateOfType<LineDropZoneState>()!;

  @override
  State<LineDropZone> createState() => LineDropZoneState();
}

class LineDropZoneState extends State<LineDropZone> {
  final _targets = <_LineDropTargetState>{};

  /// Where the item being dragged would go; `null` while none is
  /// dragged, or while it is over its own row.
  final _gap = ValueNotifier<LineGap?>(null);

  /// The rows' places when the drag began, top to bottom; `null` while
  /// no drag is going on.
  List<_PlacedRow>? _rows;

  /// Whether an item is being dragged over the rows.
  bool get dragging => _rows != null;

  List<_PlacedRow> _measure() => <_PlacedRow>[
    for (final row in _targets)
      if (row._contentBox case final box?)
        (
          row: row,
          top: box.localToGlobal(Offset.zero).dy,
          bottom: box.localToGlobal(Offset(0, box.size.height)).dy,
        ),
  ].sortedBy<num>((row) => row.top);

  /// The row the copy's middle at [middle] is over, or the nearest.
  _PlacedRow? _rowAt(double middle) => minBy(
    _rows ??= _measure(),
    (row) => middle < row.top
        ? row.top - middle
        : middle > row.bottom
        ? middle - row.bottom
        : 0.0,
  );

  void _hover(DragTargetDetails<LineDrag> details) {
    final middle = details.data.middleAt(details.offset);
    _gap.value = switch (_rowAt(middle)) {
      (:final row, :final top, :final bottom)
          when row.widget.item != details.data.item =>
        (
          item: row.widget.item,
          below: middle > (top + bottom) / 2,
          height: details.data.height,
        ),
      _ => null,
    };
  }

  void _leave() => _gap.value = null;

  void _drop(DragTargetDetails<LineDrag> details) {
    _hover(details);
    final drag = details.data;
    final row = _rowAt(drag.middleAt(details.offset))?.row;
    final below = _gap.value?.below ?? false;
    end();
    if (row == null) return;
    row.widget.onDrop(
      drag.item,
      below: below,
      levels: (drag.shiftAt(details.offset) / row.widget.step).truncate(),
    );
  }

  /// A drag began: the rows are measured at its first move, even if the
  /// last drag's end went unseen (its row was gone by then).
  void begin() => end();

  /// The drag ended: no gap, and the next drag measures the rows again.
  void end() {
    _rows = null;
    _gap.value = null;
  }

  @override
  void dispose() {
    _gap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
  late LineDropZoneState _zone;

  RenderBox? get _contentBox =>
      _content.currentContext?.findRenderObject() as RenderBox?;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _zone = LineDropZone.of(context).._targets.add(this);
  }

  @override
  void dispose() {
    _zone._targets.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DragTarget<LineDrag>(
    onMove: _zone._hover,
    onLeave: (_) => _zone._leave(),
    onAcceptWithDetails: _zone._drop,
    builder: (context, _, _) => ValueListenableBuilder(
      valueListenable: _zone._gap,
      builder: (context, gap, content) => AnimatedPadding(
        // Closes at once when the drag ends: the next drag measures the
        // rows without any gap.
        duration: _zone.dragging
            ? const Duration(milliseconds: 120)
            : Duration.zero,
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
    ),
  );
}
