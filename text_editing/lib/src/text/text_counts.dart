import 'lines.dart';

/// How many [lines] and [words] a text holds.
typedef TextCounts = ({int lines, int words});

/// [text]'s counts, as written, markup included: its lines (an empty
/// text has none; a break at the end starts none) and its words (runs
/// of characters between spaces and breaks).
TextCounts textCounts(String text) => (
  lines: text.isEmpty
      ? 0
      : splitLines(text).length - (_endsWithBreak(text) ? 1 : 0),
  words: _word.allMatches(text).length,
);

final _word = RegExp(r'\S+');

bool _endsWithBreak(String text) => text.endsWith('\n') || text.endsWith('\r');
