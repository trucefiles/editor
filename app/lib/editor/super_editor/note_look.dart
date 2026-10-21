import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import 'package:truce_core/truce_core.dart';

import '../ui/note_image.dart';
import 'marks/markup_text.dart';

/// The look of a note in the editor, in [theme]: lines close together like
/// a notes app's, Markdown styled by its markup; [monospace] where every
/// character shows, so the syntax lines up as in a code editor. Caret and
/// selection in the theme's colors. Images show inline, as [images] finds
/// them.
final class NoteLook {
  NoteLook(
    ThemeData theme, {
    required bool monospace,
    required NoteImages images,
  }) : stylesheet = _stylesheet(theme, monospace: monospace, images: images),
       selection = SelectionStyles(
         selectionColor: theme.colorScheme.primary.withValues(alpha: 0.3),
       ),
       handleColor = theme.colorScheme.primary,
       overlays = _overlays(theme.colorScheme.primary);

  final Stylesheet stylesheet;
  final SelectionStyles selection;
  final Color handleColor;

  /// What is drawn over the note: the caret, and on touch its handles.
  final List<SuperEditorLayerBuilder> overlays;
}

/// Where the text of a note's first line starts.
final noteFirstLinePadding = EdgeInsets.only(
  left: _lineInset,
  top: _documentPadding.top + _lineGap,
);

Stylesheet _stylesheet(
  ThemeData theme, {
  required bool monospace,
  required NoteImages images,
}) {
  final base = (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
    color: theme.colorScheme.onSurface,
    height: 1.4,
    fontFamily: monospace ? 'monospace' : null,
  );
  return Stylesheet(
    documentPadding: _documentPadding,
    rules: [
      StyleRule(
        BlockSelector.all,
        (document, node) => {
          Styles.padding: const CascadingPadding.symmetric(
            horizontal: _lineInset,
            vertical: _lineGap,
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
const _lineGap = 2.0;
