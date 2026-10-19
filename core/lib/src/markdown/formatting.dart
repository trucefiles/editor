/// Text with a selection in it, e.g. one line as a format button changes
/// it. Offsets into [text]; [start] <= [end].
typedef FormattedText = ({String text, int start, int end});

/// [text] with the selection from [start] to [end] wrapped in [mark] (e.g.
/// `**` for bold), or unwrapped if the mark already surrounds it, inside
/// or just outside. An empty selection gets an empty pair to type into.
FormattedText toggleWrap(String text, int start, int end, String mark) {
  final length = mark.length;
  final outside =
      start >= length &&
      end + length <= text.length &&
      text.substring(start - length, start) == mark &&
      text.substring(end, end + length) == mark;
  if (outside) {
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
  final inside =
      selected.length >= 2 * length &&
      selected.startsWith(mark) &&
      selected.endsWith(mark);
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
/// The selection from [start] to [end] stays on the same text.
FormattedText cycleHeading(String line, int start, int end) {
  final prefix = _heading.firstMatch(line)?[0] ?? '';
  final level = prefix.trim().length;
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

final _heading = RegExp(r'^#{1,6}(?:[ \t]+|$)');
