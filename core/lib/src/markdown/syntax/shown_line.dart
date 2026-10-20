import 'markup.dart';

/// A line as it shows: its text with its styles, and the offsets between
/// the shown text and the source text. Either formatted, its Markdown
/// syntax hidden, or as is, every character showing.
final class ShownLine {
  ShownLine._(this.text, this.markup, this._sourceOffsets, this._shownBefore);

  /// [source] with its [markup] applied, its syntax hidden.
  factory ShownLine.of(String source, List<MarkupSpan> markup) {
    final hidden = List.filled(source.length, false);
    for (final span in markup) {
      switch (span.markup) {
        case SyntaxMarkup():
          hidden.fillRange(span.start, span.end, true);
        default:
          break;
      }
    }
    final text = StringBuffer();
    final sourceOffsets = <int>[];
    final shownBefore = <int>[];
    for (var i = 0; i < source.length; i++) {
      shownBefore.add(sourceOffsets.length);
      if (hidden[i]) continue;
      sourceOffsets.add(i);
      text.write(source[i]);
    }
    shownBefore.add(sourceOffsets.length);
    sourceOffsets.add(source.length);
    return ShownLine._(
      text.toString(),
      [
        for (final span in markup)
          if (span.markup is! SyntaxMarkup)
            if (MarkupSpan(
                  span.markup,
                  shownBefore[span.start],
                  shownBefore[span.end],
                )
                case final shown when shown.end > shown.start)
              shown,
      ],
      sourceOffsets,
      shownBefore,
    );
  }

  /// [source] as is, with all its [markup], syntax included (shown
  /// dimmed); offsets are the same both ways.
  factory ShownLine.asIs(String source, List<MarkupSpan> markup) {
    final offsets = [for (var i = 0; i <= source.length; i++) i];
    return ShownLine._(source, markup, offsets, offsets);
  }

  /// What shows.
  final String text;

  /// The styles of [text], in its offsets.
  final List<MarkupSpan> markup;

  /// The source offset of each shown character, and the source length
  /// last.
  final List<int> _sourceOffsets;

  /// For each source offset, how many shown characters come before it.
  final List<int> _shownBefore;

  /// The source offset of the shown [offset]: the source offset of the
  /// character shown there, or the source's end past the last one.
  int toSource(int offset) => _sourceOffsets[offset.clamp(0, text.length)];

  /// The shown offset of the source [offset]; one inside hidden syntax
  /// goes to the next shown character.
  int fromSource(int offset) =>
      _shownBefore[offset.clamp(0, _shownBefore.length - 1)];
}
