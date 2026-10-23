import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import '../../note_text_styles.dart';

/// [Markup] as an attribution of editor text.
@immutable
final class MarkupAttribution implements Attribution {
  const MarkupAttribution(this.markup);

  final Markup markup;

  @override
  String get id => 'markup:${markup.hashCode}:${markup.runtimeType}';

  @override
  bool canMergeWith(Attribution other) => this == other;

  @override
  bool operator ==(Object other) =>
      other is MarkupAttribution && other.markup == markup;

  @override
  int get hashCode => markup.hashCode;
}

/// [text] with [markup] as attributions, and each image as a
/// placeholder for its widget, in place of the character showing it.
AttributedText markupText(String text, List<MarkupSpan> markup) {
  final images = {
    for (final span in markup)
      if (span.markup case final ImageMarkup image) span.start: image,
  };
  final attributed = AttributedText(
    String.fromCharCodes([
      for (final (offset, unit) in text.codeUnits.indexed)
        if (!images.containsKey(offset)) unit,
    ]),
    null,
    images,
  );
  for (final MarkupSpan(:markup, :start, :end) in markup) {
    if (end <= start) continue;
    attributed.addAttribution(
      MarkupAttribution(markup),
      SpanRange(start, end - 1),
    );
  }
  return attributed;
}

/// The url of the link in [text] at [offset], if any.
String? attributedLinkAt(AttributedText text, int offset) {
  for (final attribution in text.getAllAttributionsAt(offset)) {
    if (attribution case MarkupAttribution(markup: LinkMarkup(:final url))) {
      return url;
    }
  }
  return null;
}

/// How text with [attributions] looks, from [base], in the colors of
/// [colors].
TextStyle markupStyle(
  Set<Attribution> attributions,
  TextStyle base,
  ColorScheme colors,
) {
  var style = base;
  final dim = colors.onSurfaceVariant.withValues(alpha: 0.6);
  for (final attribution in attributions) {
    if (attribution is! MarkupAttribution) continue;
    style = switch (attribution.markup) {
      SyntaxMarkup() || DimmedMarkup() => style.copyWith(color: dim),
      ReplacedMarkup() => style,
      BoldMarkup() => style.copyWith(fontWeight: FontWeight.bold),
      ItalicMarkup() => style.copyWith(fontStyle: FontStyle.italic),
      StrikeMarkup() => style.copyWith(decoration: TextDecoration.lineThrough),
      CodeMarkup() => NoteTextStyles.code(
        style,
      ).copyWith(backgroundColor: colors.surfaceContainerHighest),
      CodeBlockMarkup() => NoteTextStyles.code(style),
      LinkMarkup() => style.copyWith(
        color: colors.primary,
        decoration: TextDecoration.underline,
      ),
      HeadingMarkup(:final level) => NoteTextStyles.heading(style, level),
      QuoteMarkup() => style.copyWith(
        fontStyle: FontStyle.italic,
        color: colors.onSurfaceVariant,
      ),
    };
  }
  return style;
}
