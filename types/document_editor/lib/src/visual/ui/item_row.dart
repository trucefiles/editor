import 'package:flutter/material.dart';
import 'package:truce_markdown/truce_markdown.dart' show ItemFrame, NodeId;

import '../../document_metrics.dart';
import '../visual_actions.dart';
import 'frames.dart';
import 'line_drag.dart';
import 'line_drop_zone.dart';
import 'swipe_to_indent.dart';

/// The row of [item] beside [content], the block that starts it (text,
/// or a block without text): drag handle, marker and, while
/// [active], a delete button, spaced by the document's metrics. The
/// handle and delete button take the whole row's height, so a finger
/// hits them anywhere beside the row. While dragged, the copy shows the
/// handle, the marker, [copy] and how many subitems move with it. [row]
/// keys the row as its drag copy is laid out; it stays the same while the
/// item changes level, so a drop lands where the row then shows.
class ItemRow extends StatelessWidget {
  const ItemRow({
    required this.row,
    required this.item,
    required this.content,
    required this.copy,
    required this.active,
    required this.style,
    required this.actions,
    super.key,
  });

  final GlobalKey row;
  final ItemFrame item;
  final Widget content;
  final Widget copy;
  final bool active;

  /// The document's body text style, for the marker and the subitem count.
  final TextStyle style;

  final VisualActions actions;

  @override
  Widget build(BuildContext context) {
    final metrics = DocumentMetrics.of(context);
    return Stack(
      key: row,
      children: [
        _MarkedRow(
          item,
          style: style,
          onToggle: () => actions.toggle(item.item),
          child: content,
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: metrics.handleWidth,
          child: _deleteButton(context, metrics),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: metrics.handleWidth,
          child: SwipeToIndent.keepMouseDrags(
            LineDragHandle(
              LineDrag(item.item, row: row, look: _dragged(context, metrics)),
              icon: _slotIcon(Icons.drag_indicator, metrics),
            ),
          ),
        ),
      ],
    );
  }

  /// The copy: the handle, and the marker with [ItemRow.copy] laid out
  /// as the row is, so its text lies where the row's does when it lifts
  /// and lands; below it, one level in, a ghost line telling how many
  /// subitems move with it.
  Widget _dragged(BuildContext context, DocumentMetrics metrics) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Stack(
        children: [
          _MarkedRow(item, style: style, child: copy),
          Positioned(
            left: 0,
            top: 0,
            width: metrics.handleWidth,
            child: _slotIcon(Icons.drag_indicator, metrics),
          ),
        ],
      ),
      if (item.subitems case final subitems when subitems > 0)
        _SubitemsLine(subitems, style: style, metrics: metrics),
    ],
  );

  /// Shown only while [ItemRow.active]; kept in the tree while hidden, so
  /// the row's layout stays put. Deletes the item with its subitems.
  Widget _deleteButton(BuildContext context, DocumentMetrics metrics) =>
      Visibility(
        visible: active,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        child: Tooltip(
          message: 'Delete item',
          child: InkResponse(
            onTap: () => actions.deleteItem(item.item),
            child: Align(
              alignment: Alignment.topCenter,
              child: IconTheme.merge(
                data: IconThemeData(color: Theme.of(context).disabledColor),
                child: _slotIcon(Icons.close, metrics),
              ),
            ),
          ),
        ),
      );

  /// The icon of a slot beside the row (handle, delete), by the row's
  /// first line: drawn at line size, whatever the slot's size.
  static Widget _slotIcon(IconData icon, DocumentMetrics metrics) => Padding(
    padding: EdgeInsets.only(top: metrics.itemRowInset),
    child: Icon(icon, size: metrics.handleIconSize),
  );
}

/// The ghost line under a dragged item's copy, one level in: a chip
/// with how many subitems move with it, [count].
class _SubitemsLine extends StatelessWidget {
  const _SubitemsLine(this.count, {required this.style, required this.metrics});

  final int count;
  final TextStyle style;
  final DocumentMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: metrics.handleWidth + metrics.levelIndent,
        right: metrics.handleWidth,
        bottom: metrics.itemRowInset * 2,
      ),
      child: Row(
        children: [
          DecoratedBox(
            decoration: ShapeDecoration(
              color: colors.primary,
              shape: const StadiumBorder(),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: metrics.lineGap * 2),
              child: Text(
                '+$count',
                style: style.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: (style.fontSize ?? 14) * 0.8,
                ),
              ),
            ),
          ),
          SizedBox(width: metrics.lineGap * 2),
          Expanded(
            child: Container(
              height: 2,
              color: colors.onSurface.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

/// [child] beside [item]'s marker (in [style]; its box checks or
/// unchecks by [onToggle], if given), with room for the handle and
/// delete button on its sides.
class _MarkedRow extends StatelessWidget {
  const _MarkedRow(
    this.item, {
    required this.style,
    required this.child,
    this.onToggle,
  });

  final ItemFrame item;
  final TextStyle style;
  final VoidCallback? onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final metrics = DocumentMetrics.of(context);
    final inset = metrics.itemRowInset;
    return Padding(
      padding: EdgeInsets.only(
        left: metrics.handleWidth,
        right: metrics.handleWidth,
        top: inset,
        bottom: inset,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkerView(item, style: style, onToggle: onToggle),
          Expanded(child: SwipeToIndent.keepMouseDrags(child)),
        ],
      ),
    );
  }
}

/// The whole row of [item], [child] with its indent, its [ItemRow] keyed
/// [row]: a drop or swipe anywhere on it counts (swipe right or left to
/// indent or outdent); while [item] is dragged, it fades where it was.
class MovableItem extends StatelessWidget {
  const MovableItem({
    required this.item,
    required this.row,
    required this.actions,
    required this.child,
    super.key,
  });

  final NodeId item;
  final GlobalKey row;
  final VisualActions actions;
  final Widget child;

  @override
  Widget build(BuildContext context) => LineDropTarget(
    item: item,
    row: row,
    child: SwipeToIndent(
      step: DocumentMetrics.of(context).levelIndent,
      onStart: actions.gestureStarted,
      onIndent: (from) => actions.indent(item, from),
      onOutdent: (from) => actions.outdent(item, from),
      child: ValueListenableBuilder(
        valueListenable: LineDropZone.of(context).drag,
        builder: (_, drag, child) =>
            Opacity(opacity: drag.lifted == item ? 0.3 : 1, child: child),
        child: child,
      ),
    ),
  );
}
