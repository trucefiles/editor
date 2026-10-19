import 'markup.dart';

/// A line shown formatted: its Markdown syntax hidden and list bullets
/// drawn as bullets, with the offsets between the shown text and the
/// source text.
final class VisualLine {
  VisualLine._(this.text, this.markup, this._sourceOffsets, this._shownBefore);

  /// [source] with its [markup] applied.
  factory VisualLine.of(String source, List<MarkupSpan> markup) {
    final hidden = List.filled(source.length, false);
    final bullets = <int>{};
    for (final span in markup) {
      switch (span.markup) {
        case SyntaxMarkup():
          hidden.fillRange(span.start, span.end, true);
        case BulletMarkup():
          bullets.add(span.start);
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
      text.write(bullets.contains(i) ? '•' : source[i]);
    }
    shownBefore.add(sourceOffsets.length);
    sourceOffsets.add(source.length);
    return VisualLine._(
      text.toString(),
      [
        for (final span in markup)
          if (span.markup is! SyntaxMarkup && span.markup is! BulletMarkup)
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

  /// What shows.
  final String text;

  /// The styles of [text], in its offsets; no syntax spans.
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
