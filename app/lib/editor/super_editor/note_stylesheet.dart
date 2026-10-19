import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import 'marks/markup_text.dart';

/// The look of a note in the editor, in [theme]: lines close together like
/// a notes app's, Markdown styled by its markup; [monospace] where every
/// character shows, so the syntax lines up as in a code editor.
Stylesheet noteStylesheet(ThemeData theme, {required bool monospace}) {
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
        },
      ),
    ],
    inlineTextStyler: (attributions, style) =>
        markupStyle(attributions, style, theme.colorScheme),
    selectedTextColorStrategy: defaultSelectedTextColorStrategy,
  );
}

const _documentPadding = EdgeInsets.fromLTRB(0, 8, 0, 88);
const _lineInset = 16.0;
const _lineGap = 2.0;

/// Where the text of a note's first line starts.
final noteFirstLinePadding = EdgeInsets.only(
  left: _lineInset,
  top: _documentPadding.top + _lineGap,
);

/// Selection colors in [theme].
SelectionStyles noteSelectionStyles(ThemeData theme) => SelectionStyles(
  selectionColor: theme.colorScheme.primary.withValues(alpha: 0.3),
);
