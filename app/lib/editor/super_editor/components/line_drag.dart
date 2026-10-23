import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

/// The handle that drags [item], whose row is [row]: a copy of the row,
/// [preview], follows the pointer meanwhile, as if the row itself moved.
/// It takes drags all over the space it is given, its [icon] drawn at the
/// top, in the middle of its width.
class LineDragHandle extends StatelessWidget {
  const LineDragHandle({
    required this.item,
    required this.row,
    required this.preview,
    required this.icon,
    this.onDragging,
    super.key,
  });

  final LineId item;
  final GlobalKey row;
  final Widget preview;
  final Widget icon;

  /// The drag started (`true`) or ended (`false`).
  final ValueChanged<bool>? onDragging;

  RenderBox get _rowBox => row.currentContext!.findRenderObject()! as RenderBox;

  @override
  Widget build(BuildContext context) => Draggable<LineDrag>(
    data: LineDrag(item, row),
    hitTestBehavior: HitTestBehavior.opaque,
    // The copy starts right over the row, where the pointer took it.
    dragAnchorStrategy: (_, _, position) => _rowBox.globalToLocal(position),
    feedbackOffset: Offset.zero,
    onDragStarted: () => onDragging?.call(true),
    onDragEnd: (_) => onDragging?.call(false),
    // The copy shows in the app's overlay; it keeps the row's media
    // settings, e.g. its text zoom, so it looks like the row.
    feedback: MediaQuery(
      data: MediaQuery.of(context),
      child: Builder(
        builder: (context) => SizedBox(
          width: _rowBox.size.width,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(4),
            child: preview,
          ),
        ),
      ),
    ),
    child: MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Align(alignment: Alignment.topCenter, child: icon),
    ),
  );
}

/// The item [item], by its marker line, being dragged; its row is [row].
@immutable
final class LineDrag {
  const LineDrag(this.item, this.row);

  final LineId item;
  final GlobalKey row;

  RenderBox get _rowBox => row.currentContext!.findRenderObject()! as RenderBox;

  double get height => _rowBox.size.height;

  /// How far right of its row the dragged copy at [offset] is.
  double shiftAt(Offset offset) =>
      offset.dx - _rowBox.localToGlobal(Offset.zero).dx;
}

/// Takes items dropped on [child], the row of [item]:
/// a copy whose middle is over the row's upper half goes above it, else
/// below it. Meanwhile a gap opens there, as large as the dragged row. A
/// row's own copy, shifted sideways by whole [step]s, goes that many
/// levels deeper or shallower.
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

  /// Where a dragged item hovering here would go, and the gap it takes;
  /// `null` while none hovers.
  ({bool below, double height})? _gap;

  /// Whether the dragged copy's middle is below this row's: measured from
  /// the row's top as without the gap, which moves the row as it opens.
  bool _isBelow(DragTargetDetails<LineDrag> details) {
    final target = context.findRenderObject()! as RenderBox;
    final content = _content.currentContext!.findRenderObject()! as RenderBox;
    final middle = details.offset.dy + details.data.height / 2;
    return target.globalToLocal(Offset(0, middle)).dy > content.size.height / 2;
  }

  bool _isSelf(LineDrag drag) => drag.item == widget.item;

  void _hover(DragTargetDetails<LineDrag> details) {
    final gap = _isSelf(details.data)
        ? null
        : (below: _isBelow(details), height: details.data.height);
    if (gap != _gap) setState(() => _gap = gap);
  }

  @override
  Widget build(BuildContext context) {
    final gap = _gap;
    return DragTarget<LineDrag>(
      onMove: _hover,
      onLeave: (_) => setState(() => _gap = null),
      onAcceptWithDetails: (details) {
        final drag = details.data;
        widget.onDrop(
          drag.item,
          below: _isBelow(details),
          levels: (drag.shiftAt(details.offset) / widget.step).truncate(),
        );
        setState(() => _gap = null);
      },
      builder: (context, _, _) => AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.only(
          top: gap != null && !gap.below ? gap.height : 0,
          bottom: gap != null && gap.below ? gap.height : 0,
        ),
        child: KeyedSubtree(key: _content, child: widget.child),
      ),
    );
  }
}
