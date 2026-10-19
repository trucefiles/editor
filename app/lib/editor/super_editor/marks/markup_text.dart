import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

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

/// [text] with [markup] as attributions.
AttributedText markupText(String text, List<MarkupSpan> markup) {
  final attributed = AttributedText(text);
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
String? linkAt(AttributedText text, int offset) {
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
      BoldMarkup() => style.copyWith(fontWeight: FontWeight.bold),
      ItalicMarkup() => style.copyWith(fontStyle: FontStyle.italic),
      StrikeMarkup() => style.copyWith(decoration: TextDecoration.lineThrough),
      CodeMarkup() => style.copyWith(
        fontFamily: 'monospace',
        backgroundColor: colors.surfaceContainerHighest,
      ),
      CodeBlockMarkup() => style.copyWith(fontFamily: 'monospace'),
      LinkMarkup() => style.copyWith(
        color: colors.primary,
        decoration: TextDecoration.underline,
      ),
      HeadingMarkup(:final level) => style.copyWith(
        fontWeight: FontWeight.bold,
        fontSize: (base.fontSize ?? 16) * _headingScale(level),
      ),
      QuoteMarkup() => style.copyWith(
        fontStyle: FontStyle.italic,
        color: colors.onSurfaceVariant,
      ),
    };
  }
  return style;
}

double _headingScale(int level) => switch (level) {
  1 => 1.5,
  2 => 1.3,
  3 => 1.15,
  _ => 1.0,
};
