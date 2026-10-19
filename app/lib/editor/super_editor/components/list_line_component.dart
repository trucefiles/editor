import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import 'line_actions.dart';
import 'line_drag.dart';
import 'swipe_to_indent.dart';

/// Indent per list level.
const _levelIndent = 28.0;

/// Width before the marker, where an item's drag handle sits.
const _handleWidth = 24.0;

/// One list item: drag handle, its [marker] (box, bullet or number) and
/// text, plus a menu while the caret is in it. Swipe right or left to
/// indent or outdent. With no [actions] it is only shown: no handle, menu
/// or swipe.
class ListLineComponent extends StatefulWidget {
  const ListLineComponent({
    required this.viewModel,
    required this.indent,
    required this.marker,
    this.struckThrough = false,
    this.actions,
    super.key,
  });

  final TextComponentViewModel viewModel;

  /// Nesting level: 0 at the left margin.
  final int indent;
  final Widget marker;

  /// Whether the text shows struck through and faded, as a checked item.
  final bool struckThrough;
  final LineActions? actions;

  @override
  State<ListLineComponent> createState() => _ListLineComponentState();
}

enum _ItemAction { indent, outdent, delete }

class _ListLineComponentState extends State<ListLineComponent>
    with ProxyDocumentComponent<ListLineComponent>, ProxyTextComposable {
  final _textKey = GlobalKey();

  @override
  GlobalKey get childDocumentComponentKey => _textKey;

  @override
  TextComposable get childTextComposable =>
      _textKey.currentState! as TextComposable;

  String get _nodeId => widget.viewModel.nodeId;

  TextStyle _style(Set<Attribution> attributions) {
    final style = widget.viewModel.textStyleBuilder(attributions);
    if (!widget.struckThrough) return style;
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
    final actions = widget.actions;
    final row = Padding(
      padding: EdgeInsets.only(left: widget.indent * _levelIndent),
      child: Row(
        children: [
          SizedBox(
            width: _handleWidth,
            child: actions == null
                ? null
                : SwipeToIndent.keepMouseDrags(
                    LineDragHandle(
                      nodeId: _nodeId,
                      label: widget.viewModel.text.toPlainText(),
                    ),
                  ),
          ),
          SizedBox.square(
            dimension: kMinInteractiveDimension,
            child: Center(child: widget.marker),
          ),
          Expanded(
            child: SwipeToIndent.keepMouseDrags(
              TextComponent(
                key: _textKey,
                text: widget.viewModel.text,
                textDirection: widget.viewModel.textDirection,
                textAlign: widget.viewModel.textAlignment,
                textStyleBuilder: _style,
                inlineWidgetBuilders: widget.viewModel.inlineWidgetBuilders,
                textSelection: widget.viewModel.selection,
                selectionColor: widget.viewModel.selectionColor,
                highlightWhenEmpty: widget.viewModel.highlightWhenEmpty,
                underlines: widget.viewModel.createUnderlines(),
              ),
            ),
          ),
          if (actions != null) _menu(actions),
        ],
      ),
    );
    if (actions == null) return row;
    return LineDropTarget(
      nodeId: _nodeId,
      onDrop: (dragged, {required below}) =>
          actions.move(dragged, target: _nodeId, below: below),
      child: SwipeToIndent(
        step: _levelIndent,
        onIndent: () => actions.indent(_nodeId),
        onOutdent: () => actions.outdent(_nodeId),
        child: row,
      ),
    );
  }

  /// Shown only while the caret is in this item; kept in the tree while
  /// hidden, so the row's layout stays put.
  Widget _menu(LineActions actions) => Visibility(
    visible: widget.viewModel.selection != null,
    maintainState: true,
    maintainAnimation: true,
    maintainSize: true,
    child: PopupMenuButton<_ItemAction>(
      tooltip: 'Item actions',
      onSelected: (action) => switch (action) {
        _ItemAction.indent => actions.indent(_nodeId),
        _ItemAction.outdent => actions.outdent(_nodeId),
        _ItemAction.delete => actions.delete(_nodeId),
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: _ItemAction.indent, child: Text('Indent')),
        PopupMenuItem(value: _ItemAction.outdent, child: Text('Outdent')),
        PopupMenuItem(value: _ItemAction.delete, child: Text('Delete')),
      ],
    ),
  );
}
