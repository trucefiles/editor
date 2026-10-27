import 'package:flutter/foundation.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_markdown/truce_markdown.dart'
    show Formatting, Inline, LinkMark, ObjectPiece, TextFormat, VisibleText;

/// A format of visible text as an attribution of library text.
@immutable
final class FormatAttribution implements Attribution {
  const FormatAttribution(this.format);

  final TextFormat format;

  @override
  String get id => 'format:${format.name}';

  @override
  bool canMergeWith(Attribution other) => this == other;

  @override
  bool operator ==(Object other) =>
      other is FormatAttribution && other.format == format;

  @override
  int get hashCode => format.hashCode;
}

/// Text that is part of a link, as an attribution of library text.
@immutable
final class LinkMarkAttribution implements Attribution {
  const LinkMarkAttribution(this.link);

  final LinkMark link;

  @override
  String get id => 'link:${identityHashCode(link)}';

  @override
  bool canMergeWith(Attribution other) => this == other;

  @override
  bool operator ==(Object other) =>
      other is LinkMarkAttribution && identical(other.link, link);

  @override
  int get hashCode => identityHashCode(link);
}

/// What an object piece (an image or inline HTML) shows as in library
/// text: one placeholder, as it is one character of visible text.
@immutable
final class ObjectPlaceholder {
  const ObjectPlaceholder(this.inline);

  /// An image or inline HTML, as read.
  final Inline inline;

  @override
  bool operator ==(Object other) =>
      other is ObjectPlaceholder && identical(other.inline, inline);

  @override
  int get hashCode => identityHashCode(inline);
}

/// [text] as library text: its characters, each object a placeholder in
/// its place, and its formats and links as attributions. Offsets are the
/// same in both.
AttributedText attributedTextOf(VisibleText text) {
  final placeholders = <int, Object>{};
  final characters = StringBuffer();
  final spans = <(Attribution, int, int)>[];
  var offset = 0;
  for (final piece in text.pieces) {
    final start = offset;
    offset += piece.length;
    switch (piece) {
      case ObjectPiece(:final inline):
        placeholders[start] = ObjectPlaceholder(inline);
      default:
        characters.write(piece.shown);
    }
    final Formatting(:formats, :link) = piece.formatting;
    spans.addAll([
      for (final format in formats) (FormatAttribution(format), start, offset),
      if (link != null) (LinkMarkAttribution(link), start, offset),
    ]);
  }
  final attributed = AttributedText(characters.toString(), null, placeholders);
  for (final (attribution, start, end) in spans) {
    if (end > start) {
      attributed.addAttribution(attribution, SpanRange(start, end - 1));
    }
  }
  return attributed;
}
