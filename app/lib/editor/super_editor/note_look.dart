import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import 'package:truce_core/truce_core.dart';

import '../note_metrics.dart';
import '../note_text_styles.dart';
import '../ui/note_image.dart';
import 'marks/markup_text.dart';

/// The look of a note in the editor, in [theme]: lines close together like
/// a notes app's, spaced by [metrics], Markdown styled by its markup;
/// [monospace] where every character shows, so the syntax lines up as in
/// a code editor. Caret and selection in the theme's colors. Images show
/// inline, as [images] finds them.
final class NoteLook {
  NoteLook(
    ThemeData theme, {
    required NoteMetrics metrics,
    required bool monospace,
    required NoteImages images,
  }) : stylesheet = _stylesheet(
         theme,
         metrics: metrics,
         monospace: monospace,
         images: images,
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

  /// Where the text of a note's first line starts.
  final EdgeInsets firstLinePadding;

  final SelectionStyles selection;
  final Color handleColor;

  /// What is drawn over the note: the caret, and on touch its handles.
  final List<SuperEditorLayerBuilder> overlays;
}

Stylesheet _stylesheet(
  ThemeData theme, {
  required NoteMetrics metrics,
  required bool monospace,
  required NoteImages images,
}) {
  final body = NoteTextStyles.body(theme);
  final base = monospace ? NoteTextStyles.monospace(body) : body;
  return Stylesheet(
    documentPadding: _documentPadding,
    rules: [
      StyleRule(
        BlockSelector.all,
        (document, node) => {
          Styles.padding: CascadingPadding.symmetric(
            horizontal: _lineInset,
            vertical: metrics.lineGap,
          ),
          Styles.textStyle: base,
          Styles.inlineWidgetBuilders: <InlineWidgetBuilder>[
            (context, style, placeholder) => switch (placeholder) {
              ImageMarkup(:final url, :final alt) => NoteImage(
                url,
                alt: alt,
                images: images,
              ),
              _ => null,
            },
          ],
        },
      ),
    ],
    inlineTextStyler: (attributions, style) =>
        markupStyle(attributions, style, theme.colorScheme),
    selectedTextColorStrategy: defaultSelectedTextColorStrategy,
  );
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
