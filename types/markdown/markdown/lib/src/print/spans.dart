/// Which spans of formatting delimiters can write, and the delimiters
/// that write them: the one owner of span rules for the writable form
/// and the printer.
library;

import 'package:collection/collection.dart';

import '../read/syntax/delimiter_runs.dart';
import '../visible/formatting.dart';
import 'char_classes.dart';

/// One thing on a level of text, as span rules see it: its span formats,
/// the classes of the first and last character it prints, and whether
/// spans leave it out at their edges.
typedef SpanItem = ({
  Set<TextFormat> spans,
  CharClass first,
  CharClass last,
  bool space,
});

/// How a text writes its spans: `*` or `_`, `**` or `__`, `~~` or `~`.
typedef SpanStyle = ({String emphasis, String strong, String strike});

/// A level's span formats as delimiters can write them, and the marks
/// at each place between its items: [marks] has one more entry than
/// [spans].
typedef LevelSpans = ({List<Set<TextFormat>> spans, List<String> marks});

/// The spans of [items] as delimiters can write them, between [edge]s of
/// a class (whitespace at a text's ends, punctuation in a link's text):
/// whitespace at a span's edges moves out, crossing spans shrink until
/// they nest, and an edge no delimiter can open or close at moves in by
/// up to three items, else its span goes. Writes `_` and `__` only where
/// [style] prefers them and they read alone.
LevelSpans writableSpans(
  List<SpanItem> items, {
  required CharClass edge,
  required SpanStyle style,
}) {
  final level = _Level(items, edge);
  level.settle();
  final runs = level.runs();
  final underscored = {
    for (final run in runs)
      if (level.readsWithUnderscore(run, style, runs)) run,
  };
  return (
    spans: [for (final spans in level.spans) Set.unmodifiable(spans)],
    marks: [
      for (var at = 0; at <= items.length; at++)
        level.marksAt(at, runs, (run) => _delimiter(run, style, underscored)),
    ],
  );
}

/// The span formats, outermost first where spans cover the same text.
const _ranked = [TextFormat.strike, TextFormat.strong, TextFormat.emphasis];

/// A maximal run of items with one [format].
typedef _Run = ({TextFormat format, int start, int end});

/// A delimiter run of [char] from [start] to [end] in [marks], the
/// delimiters at one place.
typedef _DelimiterRun = ({String char, String marks, int start, int end});

String _delimiter(_Run run, SpanStyle style, Set<_Run> underscored) =>
    switch (run.format) {
      TextFormat.strike => style.strike,
      TextFormat.strong => underscored.contains(run) ? '__' : '**',
      _ => underscored.contains(run) ? '_' : '*',
    };

/// The indexes from [from] to [to].
Iterable<int> _indexes(int from, int to) =>
    Iterable<int>.generate(to - from, (offset) => from + offset);

String _starDelimiter(_Run run, String strike) => switch (run.format) {
  TextFormat.strike => strike,
  TextFormat.strong => '**',
  _ => '*',
};

final class _Level {
  _Level(this.items, this.edge)
    : spans = [
        for (final item in items) {...item.spans},
      ];

  final List<SpanItem> items;
  final CharClass edge;

  /// The span formats each item has now.
  final List<Set<TextFormat>> spans;

  /// Fixes spans until all can be written. Each fix takes a format off
  /// an item, so this ends.
  void settle() {
    while (_trimmed() || _uncrossed() || _snapped()) {}
  }

  List<_Run> runs() => [
    for (final format in _ranked)
      for (var at = 0; at < items.length; at++)
        if (spans[at].contains(format) &&
            (at == 0 || !spans[at - 1].contains(format)))
          (format: format, start: at, end: _endOf(format, at)),
  ];

  /// Where the run of [format] from [start] ends.
  int _endOf(TextFormat format, int start) => _indexes(
    start,
    items.length,
  ).firstWhere((at) => !spans[at].contains(format), orElse: () => items.length);

  void _remove(TextFormat format, int from, int to) {
    for (var at = from; at < to; at++) {
      spans[at].remove(format);
    }
  }

  /// Takes whitespace at spans' edges out of them.
  bool _trimmed() {
    var changed = false;
    for (final run in runs()) {
      final start = _indexes(
        run.start,
        run.end,
      ).firstWhere((at) => !items[at].space, orElse: () => run.end);
      final end =
          _indexes(
            start,
            run.end,
          ).lastWhere((at) => !items[at].space, orElse: () => start - 1) +
          1;
      if (start == run.start && end == run.end) continue;
      _remove(run.format, run.start, start);
      _remove(run.format, end, run.end);
      changed = true;
    }
    return changed;
  }

  /// Shrinks the first two spans that cross, losing as little as can be.
  bool _uncrossed() {
    final runs = this.runs();
    for (final a in runs) {
      for (final b in runs) {
        if (a.start < b.start && b.start < a.end && a.end < b.end) {
          final fixes = [
            (b.format, a.end, b.end),
            (a.format, a.start, b.start),
            (a.format, b.start, a.end),
            (b.format, b.start, a.end),
          ];
          final (format, from, to) = minBy(fixes, (fix) => fix.$3 - fix.$2)!;
          _remove(format, from, to);
          return true;
        }
      }
    }
    return false;
  }

  /// Moves in, or else drops, the first span edge no delimiter can open
  /// or close at.
  bool _snapped() {
    final runs = this.runs();
    for (final run in runs) {
      for (final opens in [true, false]) {
        if (_fits(run, opens, runs)) continue;
        final others = runs.where((other) => other != run).toList();
        final moved = [
          for (var by = 1; by <= 3 && by < run.end - run.start; by++)
            opens
                ? (format: run.format, start: run.start + by, end: run.end)
                : (format: run.format, start: run.start, end: run.end - by),
        ].firstWhereOrNull((moved) => _fits(moved, opens, [...others, moved]));
        if (moved == null) {
          _remove(run.format, run.start, run.end);
        } else {
          _remove(run.format, run.start, moved.start);
          _remove(run.format, moved.end, run.end);
        }
        return true;
      }
    }
    return false;
  }

  /// Whether [run]'s opening (or closing) delimiter opens (or closes)
  /// among the delimiters of [runs], all written with `*`.
  bool _fits(_Run run, bool opens, List<_Run> runs) {
    final at = opens ? run.start : run.end;
    final delimiters = _delimiterRun(run, at, runs);
    final (:char, :marks, :start, :end) = delimiters;
    final (canOpen, canClose) = delimiterRunFlanks(
      char,
      end - start,
      before: start > 0 ? marks[start - 1] : _classBefore(at),
      after: end < marks.length ? marks[end] : _classAfter(at),
    );
    // A run that can close and opens a span closes an enclosing span of
    // its character instead, unless the rule of three keeps them apart:
    // it doesn't fit.
    final ambiguous =
        canOpen &&
        canClose &&
        runs.any((mark) => mark.start == at) &&
        runs.any(
          (other) =>
              other.start < at &&
              other.end > at &&
              _starDelimiter(other, '~~')[0] == char &&
              _canMatch(_delimiterRun(other, other.start, runs), delimiters),
        );
    return !ambiguous && (opens ? canOpen : canClose);
  }

  /// The delimiter run [run]'s delimiter at [at] is in, among the
  /// [marks] there, all written with `*`.
  _DelimiterRun _delimiterRun(_Run run, int at, List<_Run> runs) {
    final ordered = _ordered(at, runs);
    final marks = ordered.map((mark) => _starDelimiter(mark, '~~')).join();
    final offset = ordered
        .take(ordered.indexOf(run))
        .map((mark) => _starDelimiter(mark, '~~').length)
        .sum;
    final char = marks[offset];
    final end = offset + _starDelimiter(run, '~~').length;
    return (
      char: char,
      marks: marks,
      start:
          offset -
          _sameCount(marks.substring(0, offset).split('').reversed, char),
      end: end + _sameCount(marks.substring(end).split(''), char),
    );
  }

  /// Whether [opener] and [closer] can match, one of them able to open
  /// and close: not when the sum of their lengths is a multiple of three,
  /// unless both lengths are.
  bool _canMatch(_DelimiterRun opener, _DelimiterRun closer) {
    final a = opener.end - opener.start;
    final b = closer.end - closer.start;
    return (a + b) % 3 != 0 || (a % 3 == 0 && b % 3 == 0);
  }

  /// How many of [chars] are [char] before another one.
  int _sameCount(Iterable<String> chars, String char) =>
      chars.takeWhile((other) => other == char).length;

  String _classBefore(int at) =>
      representativeOf(at == 0 ? edge : items[at - 1].last);

  String _classAfter(int at) =>
      representativeOf(at == items.length ? edge : items[at].first);

  /// The runs that close and then open at [at]: closing ones innermost
  /// first, opening ones outermost first.
  List<_Run> _ordered(int at, List<_Run> runs) => [
    ...runs
        .where((run) => run.end == at)
        .sorted(
          (a, b) => b.start != a.start
              ? b.start - a.start
              : _ranked.indexOf(b.format) - _ranked.indexOf(a.format),
        ),
    ...runs
        .where((run) => run.start == at)
        .sorted(
          (a, b) => b.end != a.end
              ? b.end - a.end
              : _ranked.indexOf(a.format) - _ranked.indexOf(b.format),
        ),
  ];

  /// The delimiters at [at], spelled by [delimiter].
  String marksAt(int at, List<_Run> runs, String Function(_Run) delimiter) =>
      _ordered(at, runs).map(delimiter).join();

  /// Whether [run] can be written with `_` as [style] prefers: alone at
  /// both its edges, where `_` opens and closes.
  bool readsWithUnderscore(_Run run, SpanStyle style, List<_Run> runs) {
    final prefers = switch (run.format) {
      TextFormat.strong => style.strong == '__',
      TextFormat.emphasis => style.emphasis == '_',
      _ => false,
    };
    if (!prefers) return false;
    bool alone(int at) => _ordered(at, runs).length == 1;
    final count = run.format == TextFormat.strong ? 2 : 1;
    final (canOpen, _) = delimiterRunFlanks(
      '_',
      count,
      before: _classBefore(run.start),
      after: _classAfter(run.start),
    );
    final (_, canClose) = delimiterRunFlanks(
      '_',
      count,
      before: _classBefore(run.end),
      after: _classAfter(run.end),
    );
    return alone(run.start) && alone(run.end) && canOpen && canClose;
  }
}
