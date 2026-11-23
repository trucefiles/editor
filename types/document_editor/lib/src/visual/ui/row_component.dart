import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../../library/caret_after_inline_widget.dart';
import '../../library/child_text.dart';
import '../visual_actions.dart';
import 'framed_row.dart';
import 'row_builder.dart';

/// One row with text (also a raw block open as text) as a [FramedRow],
/// active while the caret is in it. Text in a checked item shows struck
/// through; the caret after a picture stands as high as the line.
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
        ChildText<RowComponent>,
        CaretAfterInlineWidget<RowComponent> {
  RowViewModel get _row => widget.viewModel;

  @override
  AttributedText get shownText => _row.text;
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
      content: text,
      // The whole text, as the row shows it, so the dragged copy is as
      // high as the gap it leaves.
      copy: Text.rich(
        _row.text.computeInlineSpan(context, _style, _row.inlineWidgetBuilders),
        textDirection: _row.textDirection,
        textAlign: _row.textAlignment,
      ),
      active: _row.selection != null,
      style: _row.textStyleBuilder(const {}),
      actions: _actions,
    );
  }
}
