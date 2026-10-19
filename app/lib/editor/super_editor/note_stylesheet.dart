import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import 'markup_text.dart';

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
    documentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
    rules: [
      StyleRule(
        BlockSelector.all,
        (document, node) => {
          Styles.padding: const CascadingPadding.symmetric(
            horizontal: 16,
            vertical: 2,
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

/// Selection colors in [theme].
SelectionStyles noteSelectionStyles(ThemeData theme) => SelectionStyles(
  selectionColor: theme.colorScheme.primary.withValues(alpha: 0.3),
);
