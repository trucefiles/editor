import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

/// A text component whose caret right after an inline widget (e.g. a
/// picture) stands where it does before it: on the line's top, as high
/// as the line. Flutter places such a caret, with the downstream
/// affinity a tap or arrow key gives it, on the text's top inside a
/// taller line (`getOffsetForCaret`), while its height is the whole
/// line's (`getFullHeightForCaret`), so it sticks out below the widget;
/// the upstream affinity on the same spot gives the line's top. Checked:
/// super_editor 0.3.0-dev.52 and super_text_layout 0.1.22 (the latest)
/// pair the two calls as they are; no Flutter fix is known.
mixin CaretAfterInlineWidget<T extends StatefulWidget>
    on ProxyDocumentComponent<T> {
  /// The text shown, with its inline widgets as placeholders.
  AttributedText get shownText;

  @override
  Rect getRectForPosition(NodePosition nodePosition) =>
      super.getRectForPosition(_onLineTop(nodePosition));

  @override
  Rect getEdgeForPosition(NodePosition nodePosition) =>
      super.getEdgeForPosition(_onLineTop(nodePosition));

  /// [position], or where it is right after an inline widget, the same
  /// spot with the upstream affinity; not where the line wraps after the
  /// widget, as the upstream spot is then on the line before.
  NodePosition _onLineTop(NodePosition position) => switch (position) {
    TextNodePosition(:final offset, affinity: TextAffinity.downstream)
        when offset > 0 && shownText.placeholders.containsKey(offset - 1) =>
      switch (TextNodePosition(
        offset: offset,
        affinity: TextAffinity.upstream,
      )) {
        final upstream
            when super.getOffsetForPosition(upstream).dx ==
                super.getOffsetForPosition(position).dx =>
          upstream,
        _ => position,
      },
    _ => position,
  };
}
