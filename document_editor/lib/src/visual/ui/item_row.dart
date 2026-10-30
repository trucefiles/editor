import 'package:flutter/material.dart';
import 'package:truce_markdown/truce_markdown.dart' show NodeId;

import '../../document_metrics.dart';
import '../row_looks.dart';
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
/// handle, the marker, [copy] and how many subitems move with it.
class ItemRow extends StatefulWidget {
  const ItemRow({
    required this.item,
    required this.content,
    required this.copy,
    required this.active,
    required this.style,
    required this.actions,
    super.key,
  });

  final ItemFrame item;
  final Widget content;
  final Widget copy;
  final bool active;

  /// The document's body text style, for the marker and the subitem count.
  final TextStyle style;

  final VisualActions actions;

  @override
  State<ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<ItemRow> {
  final _rowKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final metrics = DocumentMetrics.of(context);
    final item = widget.item;
    return Stack(
      key: _rowKey,
      children: [
        _MarkedRow(
          item,
          style: widget.style,
          onToggle: () => widget.actions.toggle(item.item),
          child: widget.content,
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: metrics.handleWidth,
          child: _deleteButton(metrics),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: metrics.handleWidth,
          child: SwipeToIndent.keepMouseDrags(
            LineDragHandle(
              LineDrag(item.item, row: _rowKey, look: _dragged(metrics)),
              icon: _slotIcon(Icons.drag_indicator, metrics),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dragged(DocumentMetrics metrics) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: metrics.handleWidth,
        child: _slotIcon(Icons.drag_indicator, metrics),
      ),
      MarkerView(widget.item, style: widget.style),
      Expanded(child: widget.copy),
      if (widget.item.subitems case final subitems when subitems > 0)
        Text(
          '  +$subitems',
          style: widget.style.copyWith(color: Theme.of(context).disabledColor),
        ),
      SizedBox(width: metrics.handleWidth),
    ],
  );

  /// Shown only while [ItemRow.active]; kept in the tree while hidden, so
  /// the row's layout stays put. Deletes the item with its subitems.
  Widget _deleteButton(DocumentMetrics metrics) => Visibility(
    visible: widget.active,
    maintainState: true,
    maintainAnimation: true,
    maintainSize: true,
    child: Tooltip(
      message: 'Delete item',
      child: InkResponse(
        onTap: () => widget.actions.deleteItem(widget.item.item),
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

/// [child] beside [item]'s marker (in [style]; its box checks or
/// unchecks by [onToggle]), with room for the handle and delete button
/// on its sides.
class _MarkedRow extends StatelessWidget {
  const _MarkedRow(
    this.item, {
    required this.style,
    required this.onToggle,
    required this.child,
  });

  final ItemFrame item;
  final TextStyle style;
  final VoidCallback onToggle;
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

/// The whole row of [item], [child] with its indent: a drop or swipe
/// anywhere on it counts (swipe right or left to indent or outdent);
/// while [item] is dragged, it fades where it was.
class MovableItem extends StatelessWidget {
  const MovableItem({
    required this.item,
    required this.actions,
    required this.child,
    super.key,
  });

  final NodeId item;
  final VisualActions actions;
  final Widget child;

  @override
  Widget build(BuildContext context) => LineDropTarget(
    item: item,
    child: SwipeToIndent(
      step: DocumentMetrics.of(context).levelIndent,
      onIndent: () => actions.indent(item),
      onOutdent: () => actions.outdent(item),
      child: ValueListenableBuilder(
        valueListenable: LineDropZone.of(context).lifted,
        builder: (_, dragged, child) =>
            Opacity(opacity: dragged == item ? 0.3 : 1, child: child),
        child: child,
      ),
    ),
  );
}
