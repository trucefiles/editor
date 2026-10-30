import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../../library/child_text.dart';
import '../row_looks.dart';
import '../visual_actions.dart';
import 'framed_row.dart';
import 'row_builder.dart';

/// One row with text (also a raw block open as text) as a [FramedRow],
/// active while the caret is in it. Text in a checked item shows struck
/// through.
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
    return FramedRow(
      frames: _row.frames,
      leaf: switch (_row.look) {
        TextLook(:final leaf) => leaf.id,
        RawTextLook(:final raw) => raw.block,
        final look => throw StateError('a row without text: $look'),
      },
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
    );
  }
}
