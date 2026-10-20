import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import '../child_text.dart';
import 'frames.dart';
import 'item_actions.dart';
import 'leaf_builder.dart';
import 'line_drag.dart';
import 'swipe_to_indent.dart';

/// One text node inside its frames (see [framed]). Beside the text that
/// starts an item, its row: drag handle, marker (box, bullet or number) and a menu while the
/// caret is in it; swipe right or left to indent or outdent. Text in a
/// checked item shows struck through. With no [actions], items are only
/// shown: no handle, menu or swipe, and boxes don't toggle.
class LeafComponent extends StatefulWidget {
  const LeafComponent({required this.viewModel, this.actions, super.key});

  final LeafViewModel viewModel;
  final ItemActions? actions;

  @override
  State<LeafComponent> createState() => _LeafComponentState();
}

enum _ItemAction { indent, outdent, delete }

class _LeafComponentState extends State<LeafComponent>
    with
        ProxyDocumentComponent<LeafComponent>,
        ProxyTextComposable,
        ChildText<LeafComponent> {
  final _rowKey = GlobalKey();

  /// Whether the user drags this item: it fades where it was.
  bool _dragging = false;

  List<Frame> get _frames => widget.viewModel.frames;

  /// The item the text is right in, if any.
  ItemFrame? get _item => _frames.whereType<ItemFrame>().lastOrNull;

  TextStyle _style(Set<Attribution> attributions) {
    final style = widget.viewModel.textStyleBuilder(attributions);
    if (!(_item?.checked ?? false)) return style;
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
    final viewModel = widget.viewModel;
    final text = TextComponent(
      key: childTextKey,
      text: viewModel.text,
      textDirection: viewModel.textDirection,
      textAlign: viewModel.textAlignment,
      textStyleBuilder: _style,
      inlineWidgetBuilders: viewModel.inlineWidgetBuilders,
      textSelection: viewModel.selection,
      selectionColor: viewModel.selectionColor,
      highlightWhenEmpty: viewModel.highlightWhenEmpty,
      underlines: viewModel.createUnderlines(),
    );
    final framedText = framed(_frames, text, row: _itemRow);
    final (item, actions) = (_markedItem, widget.actions);
    if (item == null || actions == null) return framedText;
    // Around the whole row, indent included: a drop or swipe anywhere
    // on it counts.
    return LineDropTarget(
      item: item.item,
      step: itemLevelIndent,
      onDrop: (dragged, {required below, required levels}) =>
          _drop(actions, item.item, dragged, below: below, levels: levels),
      child: SwipeToIndent(
        step: itemLevelIndent,
        onIndent: () => actions.indent(item.item),
        onOutdent: () => actions.outdent(item.item),
        child: Opacity(opacity: _dragging ? 0.3 : 1, child: framedText),
      ),
    );
  }

  /// The item whose marker shows beside the text, if any.
  ItemFrame? get _markedItem => switch (_item) {
    final item? when item.showsMarker => item,
    _ => null,
  };

  /// The row of [item] beside [text], the text that starts it.
  Widget _itemRow(ItemFrame item, Widget text) {
    final actions = widget.actions;
    return Row(
      key: _rowKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: itemHandleWidth,
          child: actions == null
              ? null
              : SwipeToIndent.keepMouseDrags(
                  LineDragHandle(
                    item: item.item,
                    row: _rowKey,
                    preview: _preview(item),
                    onDragging: (dragging) =>
                        setState(() => _dragging = dragging),
                  ),
                ),
        ),
        _marker(item),
        Expanded(child: SwipeToIndent.keepMouseDrags(text)),
        if (actions != null) _menu(item, actions),
      ],
    );
  }

  Widget _marker(ItemFrame item) => MarkerView(
    item,
    style: widget.viewModel.textStyleBuilder(const {}),
    onToggle: switch (widget.actions) {
      final actions? => () => actions.toggle(item.item),
      null => null,
    },
  );

  /// How the row looks while dragged: its marker and text.
  Widget _preview(ItemFrame item) => Row(
    children: [
      const SizedBox(width: itemHandleWidth, child: Icon(Icons.drag_indicator)),
      _marker(item),
      Expanded(
        child: Text(widget.viewModel.text.toPlainText(), style: _style({})),
      ),
    ],
  );

  /// The item [dragged] dropped on [item]: next to it, at the level of
  /// the spot. Dropped on itself, it indents or outdents in place by
  /// [levels], or shallower if negative.
  void _drop(
    ItemActions actions,
    LineId item,
    LineId dragged, {
    required bool below,
    required int levels,
  }) {
    if (dragged != item) {
      actions.move(dragged, target: item, below: below);
      return;
    }
    final step = levels > 0 ? actions.indent : actions.outdent;
    for (final _ in Iterable<void>.generate(levels.abs())) {
      step(dragged);
    }
  }

  /// Shown only while the caret is in this text; kept in the tree while
  /// hidden, so the row's layout stays put.
  Widget _menu(ItemFrame item, ItemActions actions) => Visibility(
    visible: widget.viewModel.selection != null,
    maintainState: true,
    maintainAnimation: true,
    maintainSize: true,
    child: PopupMenuButton<_ItemAction>(
      tooltip: 'Item actions',
      // As high as a line of text, so the menu leaves the rows compact.
      padding: EdgeInsets.zero,
      iconSize: 20,
      style: const ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      onSelected: (action) => switch (action) {
        _ItemAction.indent => actions.indent(item.item),
        _ItemAction.outdent => actions.outdent(item.item),
        _ItemAction.delete => actions.delete(item.item),
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: _ItemAction.indent, child: Text('Indent')),
        PopupMenuItem(value: _ItemAction.outdent, child: Text('Outdent')),
        PopupMenuItem(value: _ItemAction.delete, child: Text('Delete')),
      ],
    ),
  );
}
