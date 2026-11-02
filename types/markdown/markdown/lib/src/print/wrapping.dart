/// How a printed paragraph's text breaks into lines: where its soft
/// breaks are, reflowed where it was wrapped, and split where a line got
/// too long.
library;

import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart' show anyLineBreak;

import 'escaping.dart';
import 'inline_printer.dart';

/// The width a line may have unless its paragraph has its own.
const defaultWidth = 120;

/// The narrowest a paragraph's own width can be.
const _narrowest = 60;

/// A paragraph's lines as its source has them: each line's content
/// after its containers' marks, and each whole line's width.
typedef SourceLines = ({List<String> contents, List<int> widths});

/// A line of printed text: its words, single spaces between, and the
/// hard break it ends with, if any.
typedef _Line = ({List<String> words, String? hardBreak});

/// [tokens], a paragraph's printed text, as lines after containers'
/// marks [firstPrefix] (first line) and [restPrefix] wide, escaped where
/// they would start a block.
///
/// Lines break at the soft and hard breaks, and where a word (inline
/// HTML or an image) has line ends of its own. A paragraph whose [source]
/// was wrapped (each line but the last too full for the next line's
/// first word) is reflowed to its own width from its first changed line
/// until a line ends where one ended before. Other lines are split at
/// single spaces only where they are wider than [defaultWidth].
List<String> wrappedLines(
  List<InlineToken> tokens, {
  required int firstPrefix,
  required int restPrefix,
  SourceLines? source,
}) => [
  for (final line in _wrapped(
    tokens,
    firstPrefix: firstPrefix,
    restPrefix: restPrefix,
    source: source,
  ))
    ...line.split(anyLineBreak),
];

List<String> _wrapped(
  List<InlineToken> tokens, {
  required int firstPrefix,
  required int restPrefix,
  SourceLines? source,
}) {
  final lines = _linesOf(tokens);
  int prefixAt(int line) => line == 0 ? firstPrefix : restPrefix;
  final width = source == null ? defaultWidth : _widthOf(source);
  if (source != null && _wasWrapped(source, width)) {
    final changed = lines.indexed.firstWhereOrNull(
      (line) =>
          line.$1 >= source.contents.length ||
          _rendered(line.$2) != source.contents[line.$1],
    );
    if (changed == null) return lines.map(_rendered).toList();
    return [
      ...lines.take(changed.$1).map(_rendered),
      ..._reflowed(lines.sublist(changed.$1), changed.$1, width, prefixAt),
    ];
  }
  return [
    for (final (index, line) in lines.indexed)
      ..._split(line, prefixAt(index), prefixAt(index + 1)),
  ];
}

/// A paragraph's own width: its widest line if it has several and that
/// is not too narrow, else [defaultWidth].
int _widthOf(SourceLines source) => switch (source.widths.maxOrNull) {
  final widest? when source.widths.length > 1 && widest >= _narrowest => widest,
  _ => defaultWidth,
};

/// Whether [source] was wrapped at [width]: each line but the last would
/// overflow with the next line's first word.
bool _wasWrapped(SourceLines source, int width) =>
    source.widths.length > 1 &&
    Iterable<int>.generate(source.widths.length - 1).every(
      (index) =>
          source.widths[index] +
              1 +
              source.contents[index + 1].trimLeft().split(' ').first.length >
          width,
    );

List<_Line> _linesOf(List<InlineToken> tokens) {
  final lines = <_Line>[];
  var words = <String>[];
  for (final token in tokens) {
    switch (token) {
      case WordToken(:final source):
        words.add(source);
      case SpaceToken():
        break;
      case SoftBreakToken():
        lines.add((words: words, hardBreak: null));
        words = [];
      case HardBreakToken(:final spelling):
        // A line of only a break (after another) is one empty word.
        lines.add((words: words.isEmpty ? [''] : words, hardBreak: spelling));
        words = [];
    }
  }
  return [...lines, (words: words, hardBreak: null)];
}

String _rendered(_Line line) =>
    lineStartEscaped('${line.words.join(' ')}${line.hardBreak ?? ''}');

/// [lines] filled again to [width], the first of them being line
/// [first], until a line ends where one of [lines] ended; the rest stay.
List<String> _reflowed(
  List<_Line> lines,
  int first,
  int width,
  int Function(int line) prefixAt,
) {
  final words = [for (final line in lines) ...line.words];
  final ends = <int, _Line>{};
  var count = 0;
  for (final line in lines) {
    count += line.words.length;
    ends[count] = line;
  }
  final out = <String>[];
  var start = 0;
  while (start < words.length) {
    var end = start + 1;
    var length = prefixAt(first + out.length) + words[start].length;
    while (end < words.length &&
        ends[end]?.hardBreak == null &&
        length + 1 + words[end].length <= width) {
      length += 1 + words[end].length;
      end++;
    }
    final ended = ends[end];
    out.add(
      _rendered((
        words: words.sublist(start, end),
        hardBreak: ended?.hardBreak,
      )),
    );
    if (ended != null) {
      final kept = lines.skipWhile((line) => !identical(line, ended)).skip(1);
      return [...out, ...kept.map(_rendered)];
    }
    start = end;
  }
  return out;
}

/// [line] split at single spaces where it is wider than [defaultWidth]
/// after a [firstPrefix] wide prefix (and [restPrefix] on lines it
/// adds); a word wider than that stays whole.
List<String> _split(_Line line, int firstPrefix, int restPrefix) {
  final width = firstPrefix + line.words.map((word) => word.length + 1).sum - 1;
  if (width <= defaultWidth || line.words.length < 2) return [_rendered(line)];
  final out = <String>[];
  var start = 0;
  while (start < line.words.length) {
    var end = start + 1;
    var length =
        (out.isEmpty ? firstPrefix : restPrefix) + line.words[start].length;
    while (end < line.words.length &&
        length + 1 + line.words[end].length <= defaultWidth) {
      length += 1 + line.words[end].length;
      end++;
    }
    out.add(
      _rendered((
        words: line.words.sublist(start, end),
        hardBreak: end == line.words.length ? line.hardBreak : null,
      )),
    );
    start = end;
  }
  return out;
}
