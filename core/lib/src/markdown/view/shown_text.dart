import 'package:collection/collection.dart';

import 'markup.dart';

/// A block's text as it shows: its text with its styles, and the offsets
/// between the shown text and the source text. Either formatted, its
/// Markdown syntax hidden and references replaced, or as is, every
/// character showing.
final class ShownText {
  ShownText._(this.text, this.markup, this._sourceOffsets);

  /// [source] with its [markup] applied: syntax hidden, replaced ranges
  /// (see [ReplacedMarkup]) shown as what replaces them.
  factory ShownText.of(String source, List<MarkupSpan> markup) {
    final replaced = {
      for (final span in markup)
        if (span.markup case final ReplacedMarkup replaced) span.start: (
          end: span.end,
          text: replaced.text,
        ),
    };
    final hidden = {
      for (final span in markup)
        if (span.markup is SyntaxMarkup)
          for (var offset = span.start; offset < span.end; offset++) offset,
    };
    final shown = StringBuffer();
    final sourceOffsets = <int>[];
    var offset = 0;
    while (offset < source.length) {
      if (replaced[offset] case (:final end, :final text)) {
        shown.write(text);
        sourceOffsets.addAll(List.filled(text.length, offset));
        offset = end;
      } else {
        if (!hidden.contains(offset)) {
          shown.write(source[offset]);
          sourceOffsets.add(offset);
        }
        offset++;
      }
    }
    sourceOffsets.add(source.length);
    return ShownText._(shown.toString(), [
      for (final span in markup)
        if (span.markup is! SyntaxMarkup)
          if (MarkupSpan(
                span.markup,
                _shownBefore(sourceOffsets, span.start),
                _shownBefore(sourceOffsets, span.end),
              )
              case final shown when shown.end > shown.start)
            shown,
    ], sourceOffsets);
  }

  /// [source] as is, with its [markup], syntax included (shown dimmed);
  /// nothing is replaced, so offsets are the same both ways.
  factory ShownText.asIs(String source, List<MarkupSpan> markup) =>
      ShownText._(source, [
        for (final span in markup)
          if (span.markup is! ReplacedMarkup) span,
      ], null);

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
