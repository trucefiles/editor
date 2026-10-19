import 'package:flutter/material.dart';

/// The handle that drags the item of node [nodeId] to another item; the
/// item's [label] floats under the pointer meanwhile.
class LineDragHandle extends StatelessWidget {
  const LineDragHandle({required this.nodeId, required this.label, super.key});

  final String nodeId;
  final String label;

  @override
  Widget build(BuildContext context) => Draggable<LineDrag>(
    data: LineDrag(nodeId),
    // The feedback's corner is the pointer, so drop targets see where it
    // points.
    dragAnchorStrategy: pointerDragAnchorStrategy,
    feedback: Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(label),
      ),
    ),
    child: const MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Icon(Icons.drag_indicator),
    ),
  );
}

/// The item of node [nodeId], being dragged.
@immutable
final class LineDrag {
  const LineDrag(this.nodeId);

  final String nodeId;
}

/// Takes items dropped on [child], the row of the item of node [nodeId]:
/// on its upper half, they go above it, else below it. A line shows
/// where.
class LineDropTarget extends StatefulWidget {
  const LineDropTarget({
    required this.nodeId,
    required this.onDrop,
    required this.child,
    super.key,
  });

  final String nodeId;

  /// The dropped item's node, and whether it goes below.
  final void Function(String nodeId, {required bool below}) onDrop;
  final Widget child;

  @override
  State<LineDropTarget> createState() => _LineDropTargetState();
}

class _LineDropTargetState extends State<LineDropTarget> {
  /// Where a dragged item hovering here would go: below or above; `null`
  /// while none hovers.
  bool? _below;

  bool _isBelow(Offset globalPosition) {
    final box = context.findRenderObject()! as RenderBox;
    return box.globalToLocal(globalPosition).dy > box.size.height / 2;
  }

  @override
  Widget build(BuildContext context) {
    final below = _below;
    return DragTarget<LineDrag>(
      onWillAcceptWithDetails: (details) =>
          details.data.nodeId != widget.nodeId,
      onMove: (details) => setState(() => _below = _isBelow(details.offset)),
      onLeave: (_) => setState(() => _below = null),
      onAcceptWithDetails: (details) {
        widget.onDrop(details.data.nodeId, below: _isBelow(details.offset));
        setState(() => _below = null);
      },
      // Nothing over the row but while an item hovers: anything that takes
      // hits there keeps the editor from seeing taps on the row.
      builder: (context, _, _) => Stack(
        children: [
          widget.child,
          if (below != null)
            Positioned(
              left: 0,
              right: 0,
              top: below ? null : 0,
              bottom: below ? 0 : null,
              height: 2,
              child: IgnorePointer(
                child: ColoredBox(color: Theme.of(context).colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}
