import 'package:collection/collection.dart';

import '../../tree/blocks.dart';
import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';
import '../../write/inline/inline_writing.dart';
import 'whitespace.dart';

/// [text] with each delimited span that no delimiters can write (e.g.
/// bold on `"bar"` inside `foo"bar"baz`) snapped to the nearest edges
/// that can, or dropped where none can: the one check is [canWrite].
/// A line end character (one a reference showed) is never code, which
/// no code span can hold.
VisibleText representableSpans(
  VisibleText shown, {
  TextLines lines = TextLines.paragraph,
  Map<String, LinkDefinition> definitions = const {},
}) {
  final text = _lineEndsOutOfCode(shown);
  bool writes(VisibleText text) =>
      canWrite(text, lines: lines, definitions: definitions);
  if (writes(text)) return text;
  final undelimited = delimited.fold(
    text,
    (text, format) => text.reformatted(
      0,
      text.length,
      (formatting) => formatting.withFormat(format, on: false),
    ),
  );
  assert(writes(undelimited), 'text without delimited spans writes');
  final spans = [
    for (final format in delimited)
      for (final run in formatRuns(text, format)) (format: format, run: run),
  ];
  return spans.fold(
    undelimited,
    (current, span) =>
        _nearEdges(text, span.run)
            .map(
              (edges) => current.reformatted(
                edges.start,
                edges.end,
                (formatting) => formatting.withFormat(span.format, on: true),
              ),
            )
            .firstWhereOrNull(writes) ??
        current,
  );
}

/// How far a span's edge may move to find edges that write.
const _reach = 3;

/// The moves of a span's start and end, nearest first, shrinking before
/// growing.
final _moves = () {
  final steps = [
    for (final step in Iterable<int>.generate(2 * _reach + 1)) step - _reach,
  ];
  int distance((int, int) move) => move.$1.abs() + move.$2.abs();
  return [
    for (final start in steps)
      for (final end in steps) (start, end),
  ]..sort(
    (a, b) => switch (distance(a).compareTo(distance(b))) {
      0 => (a.$2 - a.$1).compareTo(b.$2 - b.$1),
      final order => order,
    },
  );
}();

/// Edges near [run] in [text], nearest first: none at whitespace.
Iterable<({int start, int end})> _nearEdges(
  VisibleText text,
  ({int start, int end}) run,
) {
  bool word(int offset) => !const [' ', '\t', '\n'].contains(text.text[offset]);
  return _moves
      .map((move) => (start: run.start + move.$1, end: run.end + move.$2))
      .where(
        (edges) =>
            edges.start >= 0 &&
            edges.end <= text.length &&
            edges.start < edges.end &&
            word(edges.start) &&
            word(edges.end - 1),
      );
}

VisibleText _lineEndsOutOfCode(VisibleText text) => [
  for (final (index, char) in text.text.split('').indexed)
    if ((char == '\n' || char == '\r') &&
        text.formattingAt(index).has(TextFormat.code))
      index,
].fold(
  text,
  (text, index) => text.reformatted(
    index,
    index + 1,
    (formatting) => formatting.withFormat(TextFormat.code, on: false),
  ),
);
