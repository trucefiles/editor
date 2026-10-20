import 'package:collection/collection.dart';

import 'markup.dart';

/// A line as it shows: its text with its styles, and the offsets between
/// the shown text and the source text. Either formatted, its Markdown
/// syntax hidden, or as is, every character showing.
final class ShownLine {
  ShownLine._(this.text, this.markup, this._sourceOffsets);

  /// [source] with its [markup] applied, its syntax hidden.
  factory ShownLine.of(String source, List<MarkupSpan> markup) {
    final hidden = {
      for (final span in markup)
        if (span.markup is SyntaxMarkup)
          for (var offset = span.start; offset < span.end; offset++) offset,
    };
    final visible = [
      for (var offset = 0; offset < source.length; offset++)
        if (!hidden.contains(offset)) offset,
    ];
    final sourceOffsets = [...visible, source.length];
    final shownMarkup = [
      for (final span in markup)
        if (span.markup is! SyntaxMarkup)
          if (MarkupSpan(
                span.markup,
                _shownBefore(sourceOffsets, span.start),
                _shownBefore(sourceOffsets, span.end),
              )
              case final shown when shown.end > shown.start)
            shown,
    ];
    return ShownLine._(
      visible.map((offset) => source[offset]).join(),
      shownMarkup,
      sourceOffsets,
    );
  }

  /// [source] as is, with all its [markup], syntax included (shown
  /// dimmed); offsets are the same both ways.
  factory ShownLine.asIs(String source, List<MarkupSpan> markup) =>
      ShownLine._(source, markup, null);

  /// What shows.
  final String text;

  /// The styles of [text], in its offsets.
  final List<MarkupSpan> markup;

  /// The source offset of each shown character, and the source length
  /// last; `null` as is, where offsets are the same both ways.
  final List<int>? _sourceOffsets;

  /// The source offset of the shown [offset]: the source offset of the
  /// character shown there, or the source's end past the last one.
  int toSource(int offset) => switch (_sourceOffsets) {
    final offsets? => offsets[offset.clamp(0, text.length)],
    null => offset,
  };

  /// The shown offset of the source [offset]; one inside hidden syntax
  /// goes to the next shown character.
  int fromSource(int offset) => switch (_sourceOffsets) {
    final offsets? => _shownBefore(offsets, offset.clamp(0, offsets.last)),
    null => offset,
  };
}

/// How many shown characters come before the source [offset], by the
/// source offsets of the shown characters, in order, and the source
/// length last.
int _shownBefore(List<int> sourceOffsets, int offset) =>
    lowerBound(sourceOffsets, offset);
