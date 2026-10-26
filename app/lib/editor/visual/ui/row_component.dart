import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../../library/child_text.dart';
import '../../note_metrics.dart';
import '../row_looks.dart';
import '../visual_actions.dart';
import 'frames.dart';
import 'line_drag.dart';
import 'line_drop_zone.dart';
import 'row_builder.dart';
import 'swipe_to_indent.dart';

/// One row with text inside its frames (see [framed]). Beside the text
/// that starts an item, its row: drag handle, marker (box, bullet or
/// number) and, while the caret is in it, a delete button; swipe right
/// or left to indent or outdent. Text in a checked item shows struck
/// through. While its item is dragged, the row fades where it was.
class RowComponent extends StatefulWidget {
  const RowComponent({
    required this.viewModel,
    required this.actions,
    super.key,
  });

  final RowViewModel viewModel;
  final VisualActions actions;

  @override
  State<RowComponent> createState() => _RowComponentState();
}

class _RowComponentState extends State<RowComponent>
    with
        ProxyDocumentComponent<RowComponent>,
        ProxyTextComposable,
        ChildText<RowComponent> {
  final _rowKey = GlobalKey();

  RowViewModel get _row => widget.viewModel;
  VisualActions get _actions => widget.actions;

  TextStyle _style(Set<Attribution> attributions) {
    final style = _row.textStyleBuilder(attributions);
    if (!(_row.item?.checked ?? false)) return style;
    return style.copyWith(
      decoration: TextDecoration.combine([
        TextDecoration.lineThrough,
        ?style.decoration,
      ]),
      color: Theme.of(context).disabledColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = TextComponent(
      key: childTextKey,
      text: _row.text,
      textDirection: _row.textDirection,
      textAlign: _row.textAlignment,
      textStyleBuilder: _style,
      inlineWidgetBuilders: _row.inlineWidgetBuilders,
      textSelection: _row.selection,
      selectionColor: _row.selectionColor,
      highlightWhenEmpty: _row.highlightWhenEmpty,
      underlines: _row.createUnderlines(),
    );
    final metrics = NoteMetrics.of(context);
    final framedText = framed(
      _row.frames,
      text,
      metrics: metrics,
      row: (item, text) => _itemRow(item, text, metrics),
    );
    final item = _row.item;
    final look = _row.look;
    if (item == null || !item.starts || look is! TextLook) return framedText;
    final lifted = LineDropZone.of(context).lifted;
    // Around the whole row, indent included: a drop or swipe anywhere
    // on it counts.
    return LineDropTarget(
      item: item.item,
      child: SwipeToIndent(
        step: metrics.levelIndent,
        onIndent: () => _actions.indent(look.leaf.id),
        onOutdent: () => _actions.outdent(look.leaf.id),
        child: ValueListenableBuilder(
          valueListenable: lifted,
          builder: (_, dragged, child) =>
              Opacity(opacity: dragged == item.item ? 0.3 : 1, child: child),
          child: framedText,
        ),
      ),
    );
  }

  /// The row of [item] beside [text], the text that starts it, spaced by
  /// [metrics]; its drag handle and delete button take the whole row's
  /// height, so a finger hits them anywhere beside the row. A raw block
  /// open as text shows only its marker.
  Widget _itemRow(ItemFrame item, Widget text, NoteMetrics metrics) {
    final look = _row.look;
    final inset = metrics.itemRowInset;
    final row = Padding(
      padding: EdgeInsets.only(
        left: metrics.handleWidth,
        right: metrics.handleWidth,
        top: inset,
        bottom: inset,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _marker(item),
          Expanded(child: SwipeToIndent.keepMouseDrags(text)),
        ],
      ),
    );
    if (look is! TextLook) return row;
    return Stack(
      key: _rowKey,
      children: [
        row,
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: metrics.handleWidth,
          child: _deleteButton(item, metrics),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: metrics.handleWidth,
          child: SwipeToIndent.keepMouseDrags(
            LineDragHandle(
              LineDrag(
                item.item,
                leaf: look.leaf.id,
                row: _rowKey,
                look: _dragged(item, metrics),
              ),
              icon: _slotIcon(Icons.drag_indicator, metrics),
            ),
          ),
        ),
      ],
    );
  }

  Widget _marker(ItemFrame item) => MarkerView(
    item,
    style: _row.textStyleBuilder(const {}),
    onToggle: () => _actions.toggle(item.item),
  );

  /// How the row looks while dragged: its handle, marker and text, and
  /// how many subitems move with it.
  Widget _dragged(ItemFrame item, NoteMetrics metrics) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: metrics.handleWidth,
        child: _slotIcon(Icons.drag_indicator, metrics),
      ),
      _marker(item),
      Expanded(
        child: Text.rich(
          TextSpan(
            text: _row.text.toPlainText(),
            style: _style(const {}),
            children: [
              if (item.subitems > 0)
                TextSpan(
                  text: '  +${item.subitems}',
                  style: _row
                      .textStyleBuilder(const {})
                      .copyWith(color: Theme.of(context).disabledColor),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      SizedBox(width: metrics.handleWidth),
    ],
  );

  /// The icon of a slot beside the row (handle, delete), by the row's
  /// first line: drawn at line size, whatever the slot's size.
  static Widget _slotIcon(IconData icon, NoteMetrics metrics) => Padding(
    padding: EdgeInsets.only(top: metrics.itemRowInset),
    child: Icon(icon, size: metrics.handleIconSize),
  );

  /// Shown only while the caret is in this text; kept in the tree while
  /// hidden, so the row's layout stays put. Deletes the item with its
  /// subitems.
  Widget _deleteButton(ItemFrame item, NoteMetrics metrics) => Visibility(
    visible: _row.selection != null,
    maintainState: true,
    maintainAnimation: true,
    maintainSize: true,
    child: Tooltip(
      message: 'Delete item',
      child: InkResponse(
        onTap: () => _actions.deleteItem(item.item),
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
}
