import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import 'line_drop_zone.dart';

/// The handle that drags [item], whose row is [row]: a copy of the row,
/// [preview], on the surface the row lies on, follows the pointer
/// meanwhile, as if the row itself moved.
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
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final surface = Material.maybeOf(context)?.color;
    return Draggable<LineDrag>(
      data: LineDrag(item, row),
      hitTestBehavior: HitTestBehavior.opaque,
      // The copy starts right over the row, where the pointer took it.
      dragAnchorStrategy: (_, _, position) => _rowBox.globalToLocal(position),
      feedbackOffset: Offset.zero,
      onDragStarted: () {
        LineDropZone.of(context).begin();
        onDragging?.call(true);
      },
      onDragEnd: (_) {
        LineDropZone.of(context).end();
        onDragging?.call(false);
      },
      // The copy shows in the app's overlay; it keeps the row's text
      // scaling, e.g. its text zoom, and the surface it lies on, e.g. the
      // note's color, so it looks like the row lifted.
      feedback: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: SizedBox(
            width: _rowBox.size.width,
            child: Material(
              color: surface,
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
}

/// The item [item], by its marker line, being dragged; its row is [row].
@immutable
final class LineDrag {
  const LineDrag(this.item, this.row);

  final LineId item;
  final GlobalKey row;

  RenderBox get _rowBox => row.currentContext!.findRenderObject()! as RenderBox;

  double get height => _rowBox.size.height;

  /// The middle of the dragged copy at [offset], from top to bottom.
  double middleAt(Offset offset) => offset.dy + height / 2;

  /// How far right of its row the dragged copy at [offset] is.
  double shiftAt(Offset offset) =>
      offset.dx - _rowBox.localToGlobal(Offset.zero).dx;
}
