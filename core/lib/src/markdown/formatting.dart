import 'syntax/block_syntax.dart';

/// Text with a selection in it, e.g. one line as a format button changes
/// it. Offsets into [text]; [start] <= [end].
typedef FormattedText = ({String text, int start, int end});

/// [text] with the selection from [start] to [end] wrapped in [mark] (e.g.
/// `**` for bold), or unwrapped if the mark already surrounds it, inside
/// or just outside. A run of mark characters holds [mark] only as
/// Markdown reads it: `*` (italic) in `*a*` and `***a***`, not in the
/// bold `**a**`, so italic on bold text makes it bold italic. An empty
/// selection gets an empty pair to type into.
FormattedText toggleWrap(String text, int start, int end, String mark) {
  final length = mark.length;
  final char = mark[0];
  final before = _runBefore(text, start, char);
  final after = _runAfter(text, end, char);
  if (_holds(before, mark) && _holds(after, mark)) {
    return (
      text:
          text.substring(0, start - length) +
          text.substring(start, end) +
          text.substring(end + length),
      start: start - length,
      end: end - length,
    );
  }
  final selected = text.substring(start, end);
  final opening = _runAfter(selected, 0, char);
  final closing = _runBefore(selected, selected.length, char);
  final inside =
      selected.length >= 2 * length &&
      opening < selected.length &&
      _holds(opening, mark) &&
      _holds(closing, mark);
  if (inside) {
    return (
      text:
          text.substring(0, start) +
          selected.substring(length, selected.length - length) +
          text.substring(end),
      start: start,
      end: end - 2 * length,
    );
  }
  return (
    text:
        '${text.substring(0, start)}$mark$selected$mark${text.substring(end)}',
    start: start + length,
    end: end + length,
  );
}

/// Whether a run of [run] mark characters holds [mark]: a one-character
/// mark only an odd run (`*`, `***`), as `**` is another mark; a longer
/// one any run at least as long.
bool _holds(int run, String mark) =>
    mark.length == 1 ? run.isOdd : run >= mark.length;

/// How many [char]s [text] has right before [index].
int _runBefore(String text, int index, String char) {
  var at = index;
  while (at > 0 && text[at - 1] == char) {
    at--;
  }
  return index - at;
}

/// How many [char]s [text] has from [index] on.
int _runAfter(String text, int index, String char) {
  var at = index;
  while (at < text.length && text[at] == char) {
    at++;
  }
  return at - index;
}

/// [text] with the selection as a link to [url]; an empty selection gets
/// the url as the link's text. The caret goes after the link.
FormattedText insertLink(String text, int start, int end, String url) {
  final label = start == end ? url : text.substring(start, end);
  final link = '[$label]($url)';
  final caret = start + link.length;
  return (
    text: text.substring(0, start) + link + text.substring(end),
    start: caret,
    end: caret,
  );
}

/// [line] at the next heading level: none, `#`, `##`, `###`, none again.
/// The selection from [start] to [end] stays on the same text. `null` for
/// a quote, which takes no heading.
FormattedText? cycleHeading(String line, int start, int end) {
  if (quoteTextStart(line) != null) return null;
  final heading = headingMark(line);
  final prefix = line.substring(0, heading?.textStart ?? 0);
  final level = heading?.level ?? 0;
  final next = level >= 3 ? '' : '${'#' * (level + 1)} ';
  final shift = next.length - prefix.length;
  int moved(int offset) =>
      offset < prefix.length ? next.length : offset + shift;
  return (
    text: next + line.substring(prefix.length),
    start: moved(start),
    end: moved(end),
  );
}
