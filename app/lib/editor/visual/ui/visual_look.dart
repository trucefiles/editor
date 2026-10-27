import 'package:flutter/material.dart';
import 'package:truce_markdown/truce_markdown.dart' as md;

import '../../library/editor_look.dart';
import '../../note_metrics.dart';
import '../../note_text_styles.dart';
import '../../ui/note_image.dart';
import '../library/attributed_text.dart';
import '../library/library_nodes.dart';
import '../row_looks.dart';

/// How Visual edit looks in [theme]: text as it reads, headings and code
/// as such, an open raw block as its dimmed raw text; formats, links,
/// images (as [images] finds them) and inline HTML in the text.
EditorLook visualLook(
  ThemeData theme, {
  required NoteMetrics metrics,
  required NoteImages images,
}) {
  final body = NoteTextStyles.body(theme);
  final colors = theme.colorScheme;
  return EditorLook(
    theme,
    metrics: metrics,
    // Rows in frames space themselves, inside the bars of the quotes they
    // go on in.
    spacesItself: (node) => switch (lookOf(node)) {
      TextLook() || BlockLook() || RawTextLook() => true,
      DoneHeadingLook() || AddItemLook() => false,
    },
    textStyleOf: (node) => switch (lookOf(node)) {
      TextLook(leaf: md.HeadingNode(:final level)) => NoteTextStyles.heading(
        body,
        level,
      ),
      TextLook(leaf: md.CodeNode()) => NoteTextStyles.code(body),
      RawTextLook() => NoteTextStyles.monospace(
        body,
      ).copyWith(color: _dim(colors)),
      _ => body,
    },
    inlineTextStyler: (attributions, style) => attributions.fold(
      style,
      (style, attribution) => switch (attribution) {
        FormatAttribution(:final format) => _formatted(style, format, colors),
        LinkMarkAttribution() => style.copyWith(
          color: colors.primary,
          decoration: TextDecoration.underline,
        ),
        _ => style,
      },
    ),
    inlineWidgets: [
      (context, style, placeholder) => switch (placeholder) {
        ObjectPlaceholder(inline: final md.ImageInline image) => NoteImage(
          image.destination,
          alt: image.description,
          images: images,
        ),
        ObjectPlaceholder(inline: final md.HtmlInline html) => Text(
          html.source,
          style: style.copyWith(color: _dim(colors)),
        ),
        _ => null,
      },
    ],
  );
}

TextStyle _formatted(
  TextStyle style,
  md.TextFormat format,
  ColorScheme colors,
) => switch (format) {
  md.TextFormat.strong => style.copyWith(fontWeight: FontWeight.bold),
  md.TextFormat.emphasis => style.copyWith(fontStyle: FontStyle.italic),
  md.TextFormat.strike => style.copyWith(
    decoration: TextDecoration.combine([
      TextDecoration.lineThrough,
      ?style.decoration,
    ]),
  ),
  md.TextFormat.code => NoteTextStyles.code(
    style,
  ).copyWith(backgroundColor: colors.surfaceContainerHighest),
};

Color _dim(ColorScheme colors) =>
    colors.onSurfaceVariant.withValues(alpha: 0.6);
