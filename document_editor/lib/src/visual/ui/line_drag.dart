import 'package:flutter/material.dart';
import 'package:truce_markdown/truce_markdown.dart' show NodeId;

import 'line_drop_zone.dart';

/// The handle that drags [drag]'s item: a copy of its row, the drag's
/// look, on the surface the row lies on, follows the pointer meanwhile,
/// as if the row itself moved. Its [LineDropZone] owns the drag from
/// lift to settle.
/// It takes drags all over the space it is given, its [icon] drawn at the
/// top, in the middle of its width.
class LineDragHandle extends StatelessWidget {
  const LineDragHandle(this.drag, {required this.icon, super.key});

  final LineDrag drag;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final zone = LineDropZone.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final surface = Material.maybeOf(context)?.color;
    return Draggable<LineDrag>(
      data: drag,
      hitTestBehavior: HitTestBehavior.opaque,
      // The copy starts right over the row, where the pointer took it.
      dragAnchorStrategy: (_, _, position) =>
          drag.rowBox!.globalToLocal(position),
      feedbackOffset: Offset.zero,
      onDragStarted: () => zone.lift(drag),
      onDraggableCanceled: (_, offset) => zone.cancel(drag, offset),
      // The copy shows in the app's overlay; it keeps the row's text
      // scaling, e.g. its text zoom, and the surface it lies on, e.g. the
      // document's color, so it looks like the row lifted.
      feedback: drag.copy(textScaler: textScaler, surface: surface),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Align(alignment: Alignment.topCenter, child: icon),
      ),
    );
  }
}

/// The item [item] being dragged; its row is [row], which looks like
/// [look] while dragged.
@immutable
final class LineDrag {
  const LineDrag(this.item, {required this.row, required this.look});

  final NodeId item;
  final GlobalKey row;
  final Widget look;

  /// The row, while it is shown; a change from elsewhere can take it
  /// away during the drag.
  RenderBox? get rowBox => switch (row.currentContext?.findRenderObject()) {
    final RenderBox box when box.hasSize => box,
    _ => null,
  };

  /// The dragged copy: [look] as wide as the row, lifted over [surface],
  /// its text scaled by [textScaler].
  Widget copy({required TextScaler textScaler, required Color? surface}) =>
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: SizedBox(
            width: rowBox?.size.width,
            child: Material(
              color: surface,
              elevation: 4,
              borderRadius: BorderRadius.circular(4),
              child: look,
            ),
          ),
        ),
      );

  /// The dragged copy at [offset], measured on its row: its height, its
  /// middle from top to bottom, and how far right of the row it is;
  /// `null` once the row is gone.
  ({double height, double middle, double shift})? at(Offset offset) =>
      switch (rowBox) {
        final box? => (
          height: box.size.height,
          middle: offset.dy + box.size.height / 2,
          shift: offset.dx - box.localToGlobal(Offset.zero).dx,
        ),
        null => null,
      };
}
