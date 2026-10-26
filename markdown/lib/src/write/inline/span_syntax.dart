/// The marks a writer puts around new spans: emphasis and strikethrough
/// delimiters, code spans, links. Each says what reads back as the span.
library;

import '../../read/syntax/delimiter_runs.dart';
import '../../tree/inlines.dart';
import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';

/// A span's opening and closing marks.
typedef Marks = ({String open, String close});

/// Whether [marks] (a run of one delimiter character, e.g. `**`) open
/// and close a span between [before] and [after] whose text starts with
/// [first] and ends with [last]; `\n` stands for a text's start or end.
bool delimitersFit(
  Marks marks, {
  required String before,
  required String first,
  required String last,
  required String after,
}) {
  final (canOpen, _) = delimiterRunFlanks(
    marks.open[0],
    marks.open.length,
    before: before,
    after: first,
  );
  final (_, canClose) = delimiterRunFlanks(
    marks.close[0],
    marks.close.length,
    before: last,
    after: after,
  );
  return canOpen && canClose;
}

/// The first of [candidates] that fits (see [delimitersFit]); the last
/// one if none does.
Marks fittingDelimiters(
  List<Marks> candidates, {
  required String before,
  required String first,
  required String last,
  required String after,
}) => candidates.firstWhere(
  (marks) => delimitersFit(
    marks,
    before: before,
    first: first,
    last: last,
    after: after,
  ),
  orElse: () => candidates.last,
);

/// A code span that reads as [code]: a backtick run that is not in the
/// code ([ticks] long if it can be), and a space at both ends where the
/// reader would take one off or the code touches a backtick.
String codeSpanSource(String code, {int? ticks}) {
  final runs = _backtickRuns
      .allMatches(code)
      .map((match) => match[0]!.length)
      .toSet();
  final length = ticks != null && !runs.contains(ticks)
      ? ticks
      : Iterable<int>.generate(
          runs.length + 1,
          (n) => n + 1,
        ).firstWhere((n) => !runs.contains(n));
  final padded =
      code.startsWith('`') ||
      code.endsWith('`') ||
      (code.startsWith(' ') && code.endsWith(' ') && code.trim().isNotEmpty);
  final fence = '`' * length;
  final pad = padded ? ' ' : '';
  return '$fence$pad$code$pad$fence';
}

final _backtickRuns = RegExp('`+');

/// The marks of a link whose text is written as it was [read] if
/// [sameText]: those of the link it was read as where they still fit,
/// else an inline link to [destination] with [title]. A bare link is its
/// text alone.
/// A [standalone] shortcut reference is written collapsed (`[a][]`), so
/// no bracket after it can make it another link.
Marks linkMarks({
  required LinkInline? read,
  required bool sameText,
  required String destination,
  required String title,
  required LinkStyle style,
  bool standalone = false,
}) {
  if (style == LinkStyle.extendedAutolink) return (open: '', close: '');
  // An autolink's text is its destination (see `withAngleAutolinks`).
  if (style == LinkStyle.autolink) return (open: '<', close: '>');
  if (read != null) {
    final oldText = read.children.map((child) => child.source).join();
    switch (read.style) {
      case LinkStyle.inline || LinkStyle.extendedAutolink:
        return (open: read.open, close: read.close);
      case LinkStyle.reference when standalone && read.close == ']':
        return (open: read.open, close: '][]');
      // A shortcut or collapsed reference's text is its label: once it
      // changed, the old label follows it.
      case LinkStyle.reference
          when sameText || (read.close != ']' && read.close != '][]'):
        return (open: read.open, close: read.close);
      case LinkStyle.reference:
        return (open: read.open, close: '][$oldText]');
      case LinkStyle.autolink:
        break;
    }
  }
  return (
    open: '[',
    close: '](${destinationSource(destination)}${titleSource(title)})',
  );
}

/// [destination] as an inline link writes it: as is where it reads as
/// is, else between `<` and `>`.
String destinationSource(String destination) {
  final escaped = destination.replaceAllMapped(
    _escapeNeeded,
    (match) => '\\${match[0]}',
  );
  return _plainDestination.hasMatch(destination) && _balanced(destination)
      ? escaped
      : '<${escaped.replaceAll('<', r'\<').replaceAll('>', r'\>')}>';
}

/// A link title as written after its destination; empty for none.
String titleSource(String title) {
  if (title.isEmpty) return '';
  final escaped = title.replaceAllMapped(
    _escapeNeeded,
    (match) => '\\${match[0]}',
  );
  if (!title.contains('"')) return ' "$escaped"';
  if (!title.contains("'")) return " '$escaped'";
  return ' "${escaped.replaceAll('"', r'\"')}"';
}

/// A backslash before punctuation, or at the end (before the closing
/// mark), and an `&` would read as escapes and references.
final _escapeNeeded = RegExp(
  r'''\\(?=[!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~]|$)|&''',
);

final _plainDestination = RegExp(r'^[^\x00-\x20\x7f<>]+$');

bool _balanced(String text) {
  var depth = 0;
  for (final char in text.split('')) {
    if (char == '(') depth++;
    if (char == ')' && --depth < 0) return false;
  }
  return depth == 0;
}

/// The character [text] has at [index]; `\n` outside it, as delimiter
/// rules see a text's ends.
String charAround(String text, int index) =>
    index < 0 || index >= text.length ? '\n' : text[index];

/// Whether every span of [text] can be written: each run of emphasis,
/// strong or strikethrough has edges `*` (or `~`) delimiters can open
/// and close at. Commands keep their text so; the writer relies on it.
bool spansFit(VisibleText text) =>
    [TextFormat.strong, TextFormat.emphasis, TextFormat.strike].every(
      (format) => _runsOf(text, format).every((run) {
        final marks = format == TextFormat.strike ? '~~' : '*';
        return delimitersFit(
          (open: marks, close: marks),
          before: charAround(text.text, run.start - 1),
          first: text.text[run.start],
          last: text.text[run.end - 1],
          after: charAround(text.text, run.end),
        );
      }),
    );

/// The maximal runs of characters [text] shows with [format].
Iterable<({int start, int end})> _runsOf(
  VisibleText text,
  TextFormat format,
) sync* {
  int? start;
  for (var at = 0; at <= text.length; at++) {
    final has = at < text.length && text.formattingAt(at).has(format);
    if (has && start == null) start = at;
    if (!has && start != null) {
      yield (start: start, end: at);
      start = null;
    }
  }
}
