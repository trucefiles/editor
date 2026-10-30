import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../../document_metrics.dart';
import '../../library/child_text.dart';
import '../row_looks.dart';
import '../visual_actions.dart';
import 'frames.dart';
import 'item_row.dart';
import 'row_builder.dart';

/// One row with text inside its frames (see [framed]). Beside the text
/// that starts an item, its [ItemRow], the delete button shown while the
/// caret is in it; the whole row is a [MovableItem]. Text in a checked
/// item shows struck through.
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
    final look = _row.look;
    final framedText = framed(
      _row.frames,
      text,
      metrics: DocumentMetrics.of(context),
      row: (item, text) => switch (look) {
        TextLook(:final leaf) => ItemRow(
          item: item,
          leaf: leaf.id,
          content: text,
          copy: Text(
            _row.text.toPlainText(),
            style: _style(const {}),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          active: _row.selection != null,
          style: _row.textStyleBuilder(const {}),
          actions: _actions,
        ),
        // A raw block open as text shows only its marker.
        _ => MarkedRow(
          item,
          style: _row.textStyleBuilder(const {}),
          onToggle: () => _actions.toggle(item.item),
          child: text,
        ),
      },
    );
    final item = _row.item;
    if (item == null || !item.starts || look is! TextLook) return framedText;
    return MovableItem(
      item: item.item,
      leaf: look.leaf.id,
      actions: _actions,
      child: framedText,
    );
  }
}
