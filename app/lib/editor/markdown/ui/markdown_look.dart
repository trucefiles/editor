import 'package:flutter/material.dart';
import 'package:truce_markdown/truce_markdown.dart' as md;

import '../../library/editor_look.dart';
import '../../note_metrics.dart';
import '../../note_text_styles.dart';
import '../library/highlight_phase.dart';

/// How Markdown edit looks in [theme]: the text as written, in monospace
/// so its marks line up; marks and raw text dimmed, and the rest as it
/// reads (bold, headings, links).
EditorLook markdownLook(ThemeData theme, {required NoteMetrics metrics}) {
  final body = NoteTextStyles.monospace(NoteTextStyles.body(theme));
  final colors = theme.colorScheme;
  return EditorLook(
    theme,
    metrics: metrics,
    textStyleOf: (_) => body,
    inlineTextStyler: (attributions, style) => attributions
        .whereType<HighlightAttribution>()
        .fold(style, (style, attribution) {
          return _highlighted(style, attribution.highlight, colors);
        }),
  );
}

TextStyle _highlighted(
  TextStyle style,
  md.Highlight highlight,
  ColorScheme colors,
) => switch (highlight) {
  md.TextHighlight.mark || md.TextHighlight.raw => style.copyWith(
    color: colors.onSurfaceVariant.withValues(alpha: 0.6),
  ),
  md.TextHighlight.strong => style.copyWith(fontWeight: FontWeight.bold),
  md.TextHighlight.emphasis => style.copyWith(fontStyle: FontStyle.italic),
  md.TextHighlight.strike => style.copyWith(
    decoration: TextDecoration.lineThrough,
  ),
  md.TextHighlight.code => style.copyWith(
    backgroundColor: colors.surfaceContainerHighest,
  ),
  md.HeadingHighlight(:final level) => NoteTextStyles.heading(style, level),
  md.LinkHighlight() => style.copyWith(
    color: colors.primary,
    decoration: TextDecoration.underline,
  ),
};
