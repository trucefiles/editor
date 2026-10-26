/// Prints a laid-out text as Markdown inline source, in tokens a wrapper
/// can break lines between.
library;

import '../read/syntax/characters.dart';
import '../read/syntax/extended_autolinks.dart';
import '../read/syntax/link_syntax.dart';
import '../tree/inlines.dart';
import '../visible/visible_text.dart';
import 'escaping.dart';
import 'inline_cells.dart';
import 'inline_layout.dart';
import 'links.dart';

/// One piece of printed inline source.
sealed class InlineToken {
  const InlineToken();
}

/// Source no line may break in.
final class WordToken extends InlineToken {
  const WordToken(this.source);

  final String source;
}

/// A single space a line may break at.
final class SpaceToken extends InlineToken {
  const SpaceToken();
}

/// A soft line break: the line breaks here.
final class SoftBreakToken extends InlineToken {
  const SoftBreakToken();
}

/// A hard line break, written as [spelling] at its line's end.
final class HardBreakToken extends InlineToken {
  const HardBreakToken(this.spelling);

  /// `\` or two spaces.
  final String spelling;
}

/// [layout]'s text as inline source tokens: words between single spaces
/// and line breaks. A new hard break is written as [hardBreak]; one
/// read keeps its spelling, except that one before another is a `\`.
List<InlineToken> printInline(
  InlineLayout layout, {
  required String hardBreak,
}) {
  final outs = _outsOf(layout);
  final printed = _resolved(outs);
  return _tokens(outs, printed, hardBreak);
}

/// One piece of output before escaping: fixed source, a character of
/// text, a space, a line break, or the end of a bracketed link.
sealed class _Out {
  const _Out();
}

final class _Fixed extends _Out {
  const _Fixed(this.source, {this.html = false, this.beforeMore});

  final String source;

  /// Whether it is inline HTML, which no line may start with.
  final bool html;

  /// Its source where what follows would extend it (a `[`, `(` or `:`
  /// after a shortcut reference); `null` if the same.
  final String? beforeMore;
}

final class _Char extends _Out {
  const _Char(this.char, {required this.inLink, required this.cell});

  final String char;
  final bool inLink;

  /// Its index among the text's cells.
  final int cell;
}

final class _Space extends _Out {
  const _Space();
}

final class _Break extends _Out {
  const _Break(this.cell);

  final BreakCell cell;
}

final class _Close extends _Out {
  const _Close(this.link, this.form, this.open);

  final LinkElement link;
  final LinkForm form;

  /// The index of the out after its `[`.
  final int open;
}

List<_Out> _outsOf(InlineLayout layout) {
  final outs = <_Out>[];
  var cellIndex = 0;
  void marks(String marks) {
    if (marks.isNotEmpty) outs.add(_Fixed(marks));
  }

  void cell(Cell cell, {required bool inLink}) {
    outs.add(switch (cell) {
      CharCell(:final char) => _Char(char, inLink: inLink, cell: cellIndex),
      CodeCell(:final code) => _Fixed(codeSpanSource(code)),
      ObjectCell(object: ObjectPiece(inline: final ImageInline image)) =>
        switch (imageSource(image, layout.definitions)) {
          final source => _Fixed(
            source,
            beforeMore: image.close == ']' && source.endsWith(']')
                ? '$source[]'
                : null,
          ),
        },
      ObjectCell(:final object) => _Fixed(
        object.inline.source,
        html: object.inline is HtmlInline,
      ),
      final BreakCell cell => _Break(cell),
    });
    cellIndex++;
  }

  for (final (index, element) in layout.elements.indexed) {
    marks(layout.top.marks[index]);
    switch ((element, layout.forms[index])) {
      case (PlainElement(cell: final plain), _):
        cell(plain, inLink: false);
      case (final LinkElement link, final form?) when form.bracketed:
        outs.add(const _Fixed('['));
        final open = outs.length;
        final inner = layout.inner[index]!;
        for (final (at, linked) in link.cells.indexed) {
          marks(inner.marks[at]);
          cell(linked, inLink: true);
        }
        marks(inner.marks.last);
        outs.add(_Close(link, form, open));
      case (final LinkElement link, final form):
        final text = link.cells.map((cell) => (cell as CharCell).char).join();
        outs.add(_Fixed(form == LinkForm.angle ? '<$text>' : text));
        cellIndex += link.cells.length;
    }
  }
  marks(layout.top.marks.last);
  return [
    for (final (index, out) in outs.indexed)
      if (out is _Char && out.char == ' ' && _breakable(outs, index))
        const _Space()
      else
        out,
  ];
}

/// Whether a line may break at the space at [index] of [outs]: it is
/// alone between other source, no inline HTML follows it, and it does
/// not follow a tag that would start an HTML block alone on the first
/// line.
bool _breakable(List<_Out> outs, int index) =>
    index > 0 &&
    index + 1 < outs.length &&
    _solid(outs[index - 1]) &&
    _solid(outs[index + 1]) &&
    !_isHtml(outs[index + 1]) &&
    !(index == 1 && _startsHtmlBlockAlone(outs.first));

bool _startsHtmlBlockAlone(_Out out) =>
    out is _Fixed && out.html && startsHtmlBlock(out.source, alone: true);

bool _isHtml(_Out out) => out is _Fixed && out.html;

bool _solid(_Out out) => switch (out) {
  _Char(:final char) => char != ' ' && char != '\t',
  _Fixed() || _Close() => true,
  _Space() || _Break() => false,
};

/// The source of each out: characters escaped, links closed.
List<String> _resolved(List<_Out> outs) {
  final bracketAfter = List.filled(outs.length + 1, false);
  for (var index = outs.length - 1; index >= 0; index--) {
    bracketAfter[index] = bracketAfter[index + 1] || _hasBracket(outs[index]);
  }
  List<String> escaped(Set<int> bareShapes) => [
    for (final (index, out) in outs.indexed)
      if (out case _Char(:final char, :final inLink))
        escapedChar(char, (
          before: index == 0 ? null : _last(outs[index - 1]),
          after: index + 1 < outs.length ? _first(outs[index + 1]) : null,
          rest: _restAfter(outs, index),
          inLink: inLink,
          bracketAfter: bracketAfter[index + 1],
          inBareLinkShape: bareShapes.contains(index),
        ))
      else
        _plainSource(out),
  ];
  final plain = escaped(const {});
  final chars = escaped(_bareLinkShapes(outs, plain));
  return [
    for (final (index, out) in outs.indexed)
      switch (out) {
        _Close() => _closing(
          out,
          chars.sublist(out.open, index).join(),
          after: index + 1 < outs.length ? _first(outs[index + 1]) : null,
        ),
        _Fixed(:final beforeMore?)
            when index + 1 < outs.length &&
                _opensMore.hasMatch(_first(outs[index + 1]) ?? '') =>
          beforeMore,
        _ => chars[index],
      },
  ];
}

/// The indexes of the characters among [outs], [printed] so, that are
/// in no link but in text a reader would take as a bare link: in a run
/// of characters printed as they are.
Set<int> _bareLinkShapes(List<_Out> outs, List<String> printed) {
  final starts = <int>[];
  var offset = 0;
  for (final source in printed) {
    starts.add(offset);
    offset += source.length;
  }
  final source = printed.join();
  bool plain(int index) =>
      index < outs.length &&
      switch (outs[index]) {
        _Char(:final char, inLink: false) => printed[index] == char,
        _Space() => true,
        _ => false,
      };
  final found = [
    for (var index = 0; index < outs.length; index++)
      if (plain(index) && (index == 0 || !plain(index - 1)))
        ...findExtendedAutolinks(
          source,
          starts[index],
          starts[_runEnd(index, plain) - 1] +
              printed[_runEnd(index, plain) - 1].length,
        ),
  ];
  return {
    for (final (index, out) in outs.indexed)
      if (out is _Char &&
          found.any(
            (link) => link.start <= starts[index] && starts[index] < link.end,
          ))
        index,
  };
}

/// Where the run of outs that are [plain] from [start] ends.
int _runEnd(int start, bool Function(int index) plain) {
  var end = start;
  while (plain(end)) {
    end++;
  }
  return end;
}

bool _hasBracket(_Out out) => switch (out) {
  _Char(:final char) => char == ']',
  _Fixed(:final source) => source.contains(']'),
  _Close() => true,
  _ => false,
};

String? _first(_Out out) => switch (out) {
  _Fixed(:final source) => source.isEmpty ? null : source[0],
  _Char(:final char) => char,
  _Space() => ' ',
  _Break() => '\n',
  _Close() => ']',
};

String? _last(_Out out) => switch (out) {
  _Fixed(:final source) => source.isEmpty ? null : source[source.length - 1],
  _Char(:final char) => char,
  _Space() => ' ',
  _Break() => '\n',
  _Close() => ')',
};

/// The characters of text right after [index], for references.
String _restAfter(List<_Out> outs, int index) => outs
    .skip(index + 1)
    .take(40)
    .takeWhile((out) => out is _Char)
    .map((out) => (out as _Char).char)
    .join();

/// The source of an out that is not a character or a link's end.
String _plainSource(_Out out) => switch (out) {
  _Fixed(:final source) => source,
  _Space() => ' ',
  _Break(:final cell) => cell.isHard ? '\\\n' : '\n',
  _Close() || _Char() => '',
};

/// How [close] ends its link, whose text printed as [text], before
/// [after].
String _closing(_Close close, String text, {required String? after}) {
  final mark = close.link.link;
  final read = mark.read;
  if (close.form == LinkForm.reference && read != null) {
    final label = referenceLabel(read);
    final shortcut = read.close == ']' || read.close == '][]';
    if (!shortcut) return spacedLineEnds(read.close);
    if (normalizeLabel(text) != normalizeLabel(label)) {
      return '][${spacedLineEnds(label)}]';
    }
    return read.close == ']' && !_opensMore.hasMatch(after ?? '') ? ']' : '][]';
  }
  if (read != null &&
      read.style == LinkStyle.inline &&
      read.destination == mark.destination &&
      read.title == mark.title &&
      !read.close.contains(lineEnd)) {
    return read.close;
  }
  return '](${destinationSource(mark.destination)}'
      '${titleSource(mark.title)})';
}

/// What after a shortcut reference would make it another link or a
/// definition.
final _opensMore = RegExp(r'^[(\[:]');

List<InlineToken> _tokens(
  List<_Out> outs,
  List<String> printed,
  String hardBreak,
) {
  final tokens = <InlineToken>[];
  final word = StringBuffer();
  void endWord() {
    if (word.isEmpty) return;
    tokens.add(WordToken(word.toString()));
    word.clear();
  }

  for (final (index, out) in outs.indexed) {
    switch (out) {
      case _Space():
        endWord();
        tokens.add(const SpaceToken());
      case _Break(:final cell) when cell.isHard:
        endWord();
        // Alone on its line, only `\` reads as a break: spaces read as a
        // blank line.
        final alone = index > 0 && outs[index - 1] is _Break;
        tokens.add(
          HardBreakToken(
            alone
                ? r'\'
                : switch (cell.read?.style) {
                    HardBreakStyle.backslash => r'\',
                    HardBreakStyle.spaces => '  ',
                    null => hardBreak,
                  },
          ),
        );
      case _Break():
        endWord();
        tokens.add(const SoftBreakToken());
      case _:
        word.write(printed[index]);
    }
  }
  endWord();
  return tokens;
}

/// A code span that reads as [code]: a backtick run that is not in the
/// code, and a space at both ends where the reader would take one off or
/// the code touches a backtick.
String codeSpanSource(String code) {
  final runs = _backtickRuns
      .allMatches(code)
      .map((match) => match[0]!.length)
      .toSet();
  final length = Iterable<int>.generate(
    runs.length + 1,
    (n) => n + 1,
  ).firstWhere((n) => !runs.contains(n));
  final padded =
      code.startsWith('`') ||
      code.endsWith('`') ||
      (code.startsWith(' ') && code.endsWith(' ') && code.contains(_notSpace));
  final fence = '`' * length;
  final pad = padded ? ' ' : '';
  return '$fence$pad$code$pad$fence';
}

final _backtickRuns = RegExp('`+');

/// A character other than a space (U+0020), which alone a code span
/// strips.
final _notSpace = RegExp('[^ ]');
