import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../document_metrics.dart';

/// How the library draws a document being edited, in [theme]: lines close
/// together like a notes app's, spaced by [metrics]; each node's text in
/// the style [textStyleOf] gives it, styled further by its attributions
/// with [inlineTextStyler]; placeholders drawn by [inlineWidgets]. Caret,
/// selection and touch handles in the theme's colors. What Visual and
/// Markdown edit share; each says how its text looks. A node whose row
/// [spacesItself] puts the line gaps above and below it on its own.
final class EditorLook {
  EditorLook(
    ThemeData theme, {
    required DocumentMetrics metrics,
    required TextStyle Function(DocumentNode node) textStyleOf,
    required AttributionStyleAdjuster inlineTextStyler,
    List<InlineWidgetBuilder> inlineWidgets = const [],
    bool Function(DocumentNode node) spacesItself = _never,
  }) : stylesheet = Stylesheet(
         documentPadding: _documentPadding,
         rules: [
           StyleRule(
             BlockSelector.all,
             (document, node) => {
               Styles.padding: CascadingPadding.symmetric(
                 horizontal: _lineInset,
                 vertical: spacesItself(node) ? 0 : metrics.lineGap,
               ),
               Styles.textStyle: textStyleOf(node),
             },
           ),
         ],
         inlineTextStyler: inlineTextStyler,
         // Only the stylesheet's own chain reaches the text: the styler
         // drops a rule's.
         inlineWidgetBuilders: inlineWidgets,
         selectedTextColorStrategy: defaultSelectedTextColorStrategy,
       ),
       firstLinePadding = EdgeInsets.only(
         left: _lineInset,
         top: _documentPadding.top + metrics.lineGap,
       ),
       selection = SelectionStyles(
         selectionColor: theme.colorScheme.primary.withValues(alpha: 0.3),
       ),
       handleColor = theme.colorScheme.primary,
       overlays = _overlays(theme.colorScheme.primary);

  final Stylesheet stylesheet;

  /// Where the text of a document's first line starts.
  final EdgeInsets firstLinePadding;

  final SelectionStyles selection;
  final Color handleColor;

  /// What is drawn over the document: the caret, and on touch its
  /// handles.
  final List<SuperEditorLayerBuilder> overlays;
}

List<SuperEditorLayerBuilder> _overlays(Color caret) => [
  const SuperEditorIosToolbarFocalPointDocumentLayerBuilder(),
  const SuperEditorIosHandlesDocumentLayerBuilder(),
  const SuperEditorAndroidToolbarFocalPointDocumentLayerBuilder(),
  SuperEditorAndroidHandlesDocumentLayerBuilder(caretColor: caret),
  DefaultCaretOverlayBuilder(caretStyle: CaretStyle(color: caret)),
];

const _documentPadding = EdgeInsets.fromLTRB(0, 8, 0, 88);
const _lineInset = 16.0;

bool _never(DocumentNode node) => false;
