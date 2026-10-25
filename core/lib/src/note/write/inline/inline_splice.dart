import 'dart:math';

import '../../tree/inlines.dart';
import '../../tree/note_style.dart';
import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';
import 'span_syntax.dart';
import 'tokens.dart';

/// The tokens that write [text] as inline content in place of [old],
/// which shows as [oldText] (its visible text, whose link marks [text]
/// shares where it kept them).
///
/// Only the part that changed is written anew: the nodes around it are
/// kept as read, and so are the spans that hold the whole change and
/// keep their format over it. Kept characters in a part written anew
/// keep their spelling (escapes, references); new spans take the marks
/// of the spans they replace, else the note's [style]. Nothing is
/// escaped here (see `escapedSource`). At most [keptLevels] spans
/// around the change are kept, if given; with [whole], all of [old] is
/// written anew, still with the kept characters' spelling.
List<Token> spliceInlines(
  List<Inline> old,
  VisibleText oldText,
  VisibleText text,
  NoteStyle style, {
  int? keptLevels,
  bool whole = false,
}) {
  if (whole) {
    final splice = _Splice(oldText, text, style, from: 0, to: oldText.length);
    return _Region(
      splice,
      _place(old, 0),
      Formatting.plain,
    ).write(0, text.length);
  }
  final prefix = _sameAtStart(oldText, text);
  final suffix = _sameAtEnd(
    oldText,
    text,
    max: min(oldText.length, text.length) - prefix,
  );
  if (prefix == oldText.length && prefix == text.length) {
    return [...old.expand(tokensOf)];
  }
  return _Splice(
    oldText,
    text,
    style,
    from: prefix,
    to: oldText.length - suffix,
  ).nodes(old, start: 0, context: Formatting.plain, levels: keptLevels);
}

int _sameAtStart(VisibleText a, VisibleText b) {
  final length = min(a.length, b.length);
  var same = 0;
  while (same < length && a.sameCharacter(same, b, same)) {
    same++;
  }
  return same;
}

int _sameAtEnd(VisibleText a, VisibleText b, {required int max}) {
  var same = 0;
  while (same < max &&
      a.sameCharacter(a.length - 1 - same, b, b.length - 1 - same)) {
    same++;
  }
  return same;
}

/// An inline node and the visible characters it shows, from [start] to
/// [end].
typedef _Placed = ({Inline node, int start, int end});

/// One visible character of the text written anew: at [at] in the new
/// text, from [piece], with the [marks] its formatting adds to the
/// spans around.
typedef _Unit = ({int at, VisiblePiece piece, String char, Set<Object> marks});

/// One splice: the old text's characters [from] to [to] became the new
/// text's [from] to `to + delta`.
final class _Splice {
  _Splice(
    this.oldText,
    this.text,
    this.style, {
    required this.from,
    required this.to,
  }) : delta = text.length - oldText.length;

  final VisibleText oldText;
  final VisibleText text;
  final NoteStyle style;
  final int from;
  final int to;
  final int delta;

  /// Where the new characters of the change end in the new text.
  int get _changeEnd => to + delta;

  /// The old character [at] in the new text, if the change kept it.
  int? _oldIndexOf(int at) => at < from
      ? at
      : at >= _changeEnd
      ? at - delta
      : null;

  /// The tokens for [nodes], which show the old characters from [start]
  /// on, inside spans that format as [context]; at most [levels] more
  /// spans around the change are kept, if given.
  List<Token> nodes(
    List<Inline> nodes, {
    required int start,
    required Formatting context,
    required int? levels,
  }) {
    final placed = _place(nodes, start);
    final touched = [
      for (final (index, node) in placed.indexed)
        if (from < to
            ? node.start < to && node.end > from
            : node.start < from && from < node.end)
          index,
    ];
    var first =
        touched.firstOrNull ?? placed.where((node) => node.end <= from).length;
    var last = touched.lastOrNull ?? first - 1;
    while (first > 0 &&
        _crosses(
          at: first <= last ? placed[first].start : from,
          context: context,
        )) {
      first--;
    }
    while (last + 1 < placed.length &&
        _crosses(
          at: (first <= last ? placed[last].end : to) + delta,
          context: context,
        )) {
      last++;
    }
    if (first > 0 &&
        !_fitsAt(
          placed[first - 1],
          placed[first - 1].start,
          placed[first - 1].end,
        )) {
      first--;
    }
    if (last + 1 < placed.length &&
        !_fitsAt(
          placed[last + 1],
          placed[last + 1].start + delta,
          placed[last + 1].end + delta,
        )) {
      last++;
    }
    final region = placed.sublist(first, last + 1);
    final before = placed.take(first).expand((node) => tokensOf(node.node));
    final after = placed.skip(last + 1).expand((node) => tokensOf(node.node));
    if (region case [final only]
        when (levels == null || levels > 0) && _keepsSpan(only)) {
      final span = only.node as ContainerInline;
      return [
        ...before,
        FixedToken(span.open),
        ...this.nodes(
          span.children,
          start: only.start,
          context: _within(context, _markOf(only)!),
          levels: levels == null ? null : levels - 1,
        ),
        FixedToken(span.close),
        ...after,
      ];
    }
    final regionStart = region.firstOrNull?.start ?? from;
    final regionEnd = region.lastOrNull?.end ?? to;
    return [
      ...before,
      ..._Region(this, region, context).write(regionStart, regionEnd + delta),
      ...after,
    ];
  }

  /// Whether a span goes on across the new text's offset [at], beyond
  /// [context]: the characters on both sides share a mark, so they must
  /// be written in one span.
  bool _crosses({required int at, required Formatting context}) =>
      at > 0 &&
      at < text.length &&
      _marksBeyond(
        text.formattingAt(at - 1),
        context,
      ).intersection(_marksBeyond(text.formattingAt(at), context)).isNotEmpty;

  /// Whether the span [placed] stays around all of its new characters,
  /// so its marks and the nodes beside the change in it are kept.
  bool _keepsSpan(_Placed placed) {
    final mark = _markOf(placed);
    final start = placed.start;
    final end = placed.end + delta;
    return placed.node is ContainerInline &&
        mark != null &&
        _fitsAt(placed, start, end) &&
        end > start &&
        Iterable<int>.generate(
          end - start,
          (offset) => start + offset,
        ).every((at) => _has(text.formattingAt(at), mark));
  }

  /// Whether the delimiters of [placed], if it is a span of them, still
  /// open and close it around the new characters [start] to [end].
  bool _fitsAt(_Placed placed, int start, int end) => switch (placed.node) {
    EmphasisInline(:final open, :final close) ||
    StrongInline(:final open, :final close) ||
    StrikeInline(:final open, :final close) when end > start => delimitersFit(
      (open: open, close: close),
      before: charAround(text.text, start - 1),
      first: text.text[start],
      last: text.text[end - 1],
      after: charAround(text.text, end),
    ),
    _ => true,
  };

  /// The mark of a span: its format, or a link's mark in the old text;
  /// `null` for other nodes.
  Object? _markOf(_Placed placed) => switch (placed.node) {
    LinkInline() => oldText.formattingAt(placed.start).link,
    CodeInline() => TextFormat.code,
    final node => _formatOf(node),
  };
}

/// [nodes] with the visible characters each shows, from [start] on.
List<_Placed> _place(List<Inline> nodes, int start) {
  var at = start;
  return [
    for (final node in nodes)
      () {
        final placed = (node: node, start: at, end: at + visibleLength(node));
        at = placed.end;
        return placed;
      }(),
  ];
}

/// How many visible characters [node] shows.
int visibleLength(Inline node) => switch (node) {
  TextInline(:final literal) || CodeInline(:final literal) => literal.length,
  SoftBreakInline() || HardBreakInline() || HtmlInline() || ImageInline() => 1,
  ContainerInline(:final children) => children.fold(
    0,
    (sum, child) => sum + visibleLength(child),
  ),
};

bool _has(Formatting formatting, Object mark) => switch (mark) {
  TextFormat() => formatting.has(mark),
  _ => identical(formatting.link, mark),
};

Formatting _within(Formatting context, Object mark) => switch (mark) {
  final TextFormat format => context.withFormat(format, on: true),
  final LinkMark link => context.withLink(link),
  _ => context,
};

/// The marks [formatting] adds to [context].
Set<Object> _marksBeyond(Formatting formatting, Formatting context) => {
  ...formatting.formats.difference(context.formats),
  if (formatting.link case final link? when !identical(link, context.link))
    link,
};

/// A part of the text written anew: the old [nodes] it replaces, inside
/// spans that format as [context].
final class _Region {
  _Region(this.splice, List<_Placed> nodes, this.context)
    : _oldStart = nodes.isEmpty ? splice.from : nodes.first.start,
      _oldTokens = [for (final node in nodes) ..._charTokens(node.node)],
      _spans = [for (final node in nodes) ..._spansIn(node.node, node.start)];

  final _Splice splice;
  final Formatting context;
  final int _oldStart;

  /// One per old visible character of the nodes: how it was spelled, if
  /// as text.
  final List<Token?> _oldTokens;

  /// The old spans in the nodes, with the characters they showed.
  final List<_Placed> _spans;

  /// The tokens for the new text's characters from [start] to [end].
  List<Token> write(int start, int end) {
    final units = <_Unit>[];
    var at = start;
    for (final piece in splice.text.slice(start, end).pieces) {
      final marks = _marksBeyond(piece.formatting, context);
      for (final char in piece.shown.split('')) {
        units.add((at: at++, piece: piece, char: char, marks: marks));
      }
    }
    return _write(
      units,
      const {},
      inAutolink: context.link?.style == LinkStyle.extendedAutolink,
    );
  }

  List<Token> _write(
    List<_Unit> units,
    Set<Object> active, {
    required bool inAutolink,
  }) {
    final tokens = <Token>[];
    var index = 0;
    while (index < units.length) {
      final open = units[index].marks.difference(active);
      if (open.isEmpty) {
        tokens.add(_tokenOf(units[index], inAutolink: inAutolink));
        index++;
        continue;
      }
      final mark = _outermost(units, index, open);
      final end = _spanEnd(units, index, mark, active);
      tokens.addAll(
        _span(mark, units.sublist(index, end), active, inAutolink: inAutolink),
      );
      index = end;
    }
    return tokens;
  }

  /// The mark that opens at [index] and runs longest; code is innermost.
  Object _outermost(List<_Unit> units, int index, Set<Object> open) {
    final candidates = open.length > 1
        ? open.where((mark) => mark != TextFormat.code)
        : open;
    return candidates.reduce((best, mark) {
      final bestEnd = _runEnd(units, index, best);
      final end = _runEnd(units, index, mark);
      return end > bestEnd || (end == bestEnd && _rank(mark) < _rank(best))
          ? mark
          : best;
    });
  }

  /// Where the span of [mark] from [index] ends: where its run ends,
  /// unless that splits a span that overlaps its end at a place no
  /// delimiter fits; then where that span starts, so that it holds the
  /// rest of this one instead.
  int _spanEnd(List<_Unit> units, int index, Object mark, Set<Object> active) {
    final end = _runEnd(units, index, mark);
    if (end == units.length) return end;
    final crossing = units[end - 1].marks
        .intersection(units[end].marks)
        .difference({...active, mark});
    final starts = [
      for (final other in crossing)
        if (!_splitFits(units, end, other)) _runStart(units, end - 1, other),
    ].where((start) => start > index);
    return starts.isEmpty ? end : starts.reduce(min);
  }

  /// Whether a span of [mark] can be closed before [at] and opened again
  /// there.
  bool _splitFits(List<_Unit> units, int at, Object mark) {
    if (mark is! TextFormat || mark == TextFormat.code) return true;
    final marks = mark == TextFormat.strike ? '~~' : '*';
    final text = splice.text.text;
    final before = units[at - 1].at;
    final after = units[at].at;
    return delimitersFit(
          (open: marks, close: marks),
          before: charAround(text, before - 1),
          first: text[before],
          last: text[before],
          after: text[after],
        ) &&
        delimitersFit(
          (open: marks, close: marks),
          before: text[before],
          first: text[after],
          last: text[after],
          after: charAround(text, after + 1),
        );
  }

  static int _runStart(List<_Unit> units, int index, Object mark) {
    var start = index;
    while (start > 0 && units[start - 1].marks.contains(mark)) {
      start--;
    }
    return start;
  }

  static int _rank(Object mark) => switch (mark) {
    LinkMark() => 0,
    TextFormat.strong => 1,
    TextFormat.emphasis => 2,
    TextFormat.strike => 3,
    _ => 4,
  };

  static int _runEnd(List<_Unit> units, int index, Object mark) {
    var end = index;
    while (end < units.length && units[end].marks.contains(mark)) {
      end++;
    }
    return end;
  }

  List<Token> _span(
    Object mark,
    List<_Unit> run,
    Set<Object> active, {
    required bool inAutolink,
  }) {
    final inner = {...active, mark};
    switch (mark) {
      case TextFormat.code:
        return [
          FixedToken(
            codeSpanSource(
              run.map((unit) => unit.char).join(),
              ticks: _reusedTicks(run),
            ),
          ),
        ];
      case final LinkMark link:
        final children = _write(
          run,
          inner,
          inAutolink: link.style == LinkStyle.extendedAutolink,
        );
        final marks = linkMarks(
          read: link.read,
          textSource: sourceOf(children),
          destination: link.destination,
          title: link.title,
          style: link.style,
        );
        return [FixedToken(marks.open), ...children, FixedToken(marks.close)];
      case final TextFormat format:
        final children = _write(run, inner, inAutolink: inAutolink);
        final marks = _delimiters(format, run);
        return [FixedToken(marks.open), ...children, FixedToken(marks.close)];
    }
    throw ArgumentError.value(mark, 'mark', 'no span mark');
  }

  Marks _delimiters(TextFormat format, List<_Unit> run) {
    final style = splice.style;
    final preferred = switch (format) {
      TextFormat.strong => [style.strong, '**'],
      TextFormat.emphasis => [style.emphasis, '*'],
      _ => [style.strike, '~~'],
    };
    return fittingDelimiters(
      [
        if (_reused(run, (node) => _formatOf(node) == format)
            case final ContainerInline node)
          (open: node.open, close: node.close),
        for (final marks in preferred) (open: marks, close: marks),
      ],
      before: charAround(splice.text.text, run.first.at - 1),
      first: run.first.char,
      last: run.last.char,
      after: charAround(splice.text.text, run.last.at + 1),
    );
  }

  /// The length of the backtick run of the old code span [run] keeps
  /// characters of.
  int? _reusedTicks(List<_Unit> run) =>
      switch (_reused(run, (node) => node is CodeInline)) {
        CodeInline(:final source) => _ticks.matchAsPrefix(source)![0]!.length,
        _ => null,
      };

  static final _ticks = RegExp('`+');

  /// The old span that showed one of [run]'s kept characters and is
  /// [wanted].
  Inline? _reused(List<_Unit> run, bool Function(Inline node) wanted) {
    final kept = run
        .map((unit) => splice._oldIndexOf(unit.at))
        .nonNulls
        .toSet();
    return _spans
        .where(
          (span) =>
              wanted(span.node) &&
              kept.any((at) => at >= span.start && at < span.end),
        )
        .firstOrNull
        ?.node;
  }

  Token _tokenOf(_Unit unit, {required bool inAutolink}) =>
      switch (unit.piece) {
        TextPiece() => switch (_keptToken(unit.at)) {
          CharToken(:final char) => CharToken(
            char,
            changed: false,
            inAutolink: inAutolink,
          ),
          final FixedToken token => token,
          null => CharToken(unit.char, changed: true, inAutolink: inAutolink),
        },
        SoftBreakPiece(:final read) => FixedToken(read?.source ?? '\n'),
        HardBreakPiece(:final read) => FixedToken(read?.source ?? '\\\n'),
        ObjectPiece(:final inline) => FixedToken(inline.source),
      };

  Token? _keptToken(int at) => switch (splice._oldIndexOf(at)) {
    final old? when old >= _oldStart && old - _oldStart < _oldTokens.length =>
      _oldTokens[old - _oldStart],
    _ => null,
  };
}

TextFormat? _formatOf(Inline node) => switch (node) {
  EmphasisInline() => TextFormat.emphasis,
  StrongInline() => TextFormat.strong,
  StrikeInline() => TextFormat.strike,
  _ => null,
};

/// One per visible character of [node]: the token that spelled it as
/// text; `null` for code, breaks and objects.
List<Token?> _charTokens(Inline node) => switch (node) {
  TextInline(isPlain: true, :final literal) => [
    for (final char in literal.split('')) CharToken(char, changed: false),
  ],
  TextInline(:final literal, :final source) => [
    FixedToken(source),
    for (var index = 1; index < literal.length; index++) const FixedToken(''),
  ],
  ImageInline() => [null],
  ContainerInline(:final children) => [...children.expand(_charTokens)],
  CodeInline(:final literal) => List.filled(literal.length, null),
  SoftBreakInline() || HardBreakInline() || HtmlInline() => [null],
};

/// The spans in [node] and the old characters each showed, from [start]
/// on.
List<_Placed> _spansIn(Inline node, int start) => switch (node) {
  ImageInline() => const [],
  ContainerInline(:final children) => [
    (node: node, start: start, end: start + visibleLength(node)),
    for (final child in _place(children, start))
      ..._spansIn(child.node, child.start),
  ],
  CodeInline() => [
    (node: node, start: start, end: start + visibleLength(node)),
  ],
  _ => const [],
};
