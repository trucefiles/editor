import 'markup.dart';

/// The inline Markdown of [text] from [from] to [to]: emphasis, strike,
/// code, links and backslash escapes, with the ranges of their syntax
/// characters. A small subset of CommonMark and GitHub Flavored Markdown,
/// enough to style a note's lines; text it does not recognize stays
/// plain.
List<MarkupSpan> inlineMarkup(String text, [int from = 0, int? to]) =>
    _InlineScanner(text).scan(from, to ?? text.length);

final class _InlineScanner {
  _InlineScanner(this.text);

  final String text;
  final _spans = <MarkupSpan>[];

  static const _syntax = SyntaxMarkup();
  static final _punctuation = RegExp(r'''[!-/:-@\[-`{-~]''');
  static final _url = RegExp(r'''https?://[^\s<>]+''');
  static final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

  List<MarkupSpan> scan(int from, int to) {
    _scan(from, to);
    return _spans;
  }

  void _scan(int from, int to) {
    var i = from;
    while (i < to) {
      i =
          _escape(i, to) ??
          _code(i, to) ??
          _link(i, to) ??
          _autolink(i, to) ??
          _bareUrl(i, to) ??
          _emphasis(i, to) ??
          i + 1;
    }
  }

  void _add(Markup markup, int start, int end) =>
      _spans.add(MarkupSpan(markup, start, end));

  /// `\*`: the backslash is syntax, the character after it plain.
  int? _escape(int i, int to) {
    if (text[i] != r'\' || i + 1 >= to) return null;
    if (!_punctuation.hasMatch(text[i + 1])) return null;
    _add(_syntax, i, i + 1);
    return i + 2;
  }

  /// `` `code` ``: closed by a run of as many backticks.
  int? _code(int i, int to) {
    if (text[i] != '`') return null;
    final ticks = _runLength(i, to);
    for (var j = i + ticks; j < to;) {
      if (text[j] != '`') {
        j++;
        continue;
      }
      final run = _runLength(j, to);
      if (run == ticks) {
        _add(_syntax, i, i + ticks);
        _add(const CodeMarkup(), i + ticks, j);
        _add(_syntax, j, j + ticks);
        return j + ticks;
      }
      j += run;
    }
    return i + ticks;
  }

  /// `[text](url)` and `![alt](url)`; the text may hold other markup.
  int? _link(int i, int to) {
    final image = text[i] == '!' && i + 1 < to && text[i + 1] == '[';
    if (text[i] != '[' && !image) return null;
    final open = image ? i + 1 : i;
    final close = _closing(open + 1, to, ']');
    if (close == null || close + 1 >= to || text[close + 1] != '(') {
      return null;
    }
    final end = _closing(close + 2, to, ')');
    if (end == null) return null;
    final target = text.substring(close + 2, end).trim();
    final url = target.split(RegExp(r'\s+')).first;
    if (url.isEmpty) return null;
    _add(_syntax, i, open + 1);
    _add(LinkMarkup(url), open + 1, close);
    _scan(open + 1, close);
    _add(_syntax, close, end + 1);
    return end + 1;
  }

  /// `<https://example.com>`.
  int? _autolink(int i, int to) {
    if (text[i] != '<') return null;
    final match = _url.matchAsPrefix(text, i + 1);
    if (match == null || match.end >= to || text[match.end] != '>') {
      return null;
    }
    _add(_syntax, i, i + 1);
    _add(LinkMarkup(match[0]!), i + 1, match.end);
    _add(_syntax, match.end, match.end + 1);
    return match.end + 1;
  }

  /// `https://example.com` in running text, without trailing punctuation.
  int? _bareUrl(int i, int to) {
    if (i > 0 && _wordChar.hasMatch(text[i - 1])) return null;
    final match = _url.matchAsPrefix(text, i);
    if (match == null) return null;
    var end = match.end < to ? match.end : to;
    while (end > i && '.,;:!?)\'"'.contains(text[end - 1])) {
      end--;
    }
    _add(LinkMarkup(text.substring(i, end)), i, end);
    return end;
  }

  /// `*italic*`, `**bold**`, `***both***` (also with `_`), `~~strike~~`.
  int? _emphasis(int i, int to) {
    final char = text[i];
    if (char != '*' && char != '_' && char != '~') return null;
    final run = _runLength(i, to);
    final length = char == '~' ? 2 : (run > 3 ? 3 : run);
    if (run != length && char == '~') return i + run;
    if (!_opens(i, i + length, to)) return i + run;
    final close = _findCloser(char, length, i + length + 1, to);
    if (close == null) return i + run;
    _add(_syntax, i, i + length);
    if (char == '~') {
      _add(const StrikeMarkup(), i + length, close);
    } else {
      if (length >= 2) _add(const BoldMarkup(), i + length, close);
      if (length != 2) _add(const ItalicMarkup(), i + length, close);
    }
    _scan(i + length, close);
    _add(_syntax, close, close + length);
    return close + length;
  }

  /// Whether the run from [start] to [end] can open emphasis: followed by
  /// a non-space; an `_` also not right after a letter or digit.
  bool _opens(int start, int end, int to) {
    if (end >= to || _isSpace(text[end])) return false;
    return text[start] != '_' ||
        start == 0 ||
        !_wordChar.hasMatch(text[start - 1]);
  }

  /// The start of a run of [length] [char]s from [from] that can close
  /// emphasis: after a non-space; an `_` also not before a letter or digit.
  int? _findCloser(String char, int length, int from, int to) {
    for (var j = from; j < to;) {
      if (text[j] == '`') {
        // Code spans bind tighter than emphasis.
        j = _skipCode(j, to);
        continue;
      }
      if (text[j] != char) {
        j++;
        continue;
      }
      final run = _runLength(j, to);
      final closes =
          run >= length &&
          !_isSpace(text[j - 1]) &&
          (char != '_' || j + run >= to || !_wordChar.hasMatch(text[j + run]));
      if (closes) return j + run - length;
      j += run;
    }
    return null;
  }

  int _skipCode(int i, int to) {
    final ticks = _runLength(i, to);
    for (var j = i + ticks; j < to;) {
      if (text[j] != '`') {
        j++;
        continue;
      }
      final run = _runLength(j, to);
      if (run == ticks) return j + run;
      j += run;
    }
    return i + ticks;
  }

  /// The index of the first unescaped [char] from [from]; `null` if none.
  int? _closing(int from, int to, String char) {
    for (var j = from; j < to; j++) {
      if (text[j] == r'\') {
        j++;
      } else if (text[j] == char) {
        return j;
      }
    }
    return null;
  }

  int _runLength(int i, int to) {
    var end = i;
    while (end < to && text[end] == text[i]) {
      end++;
    }
    return end - i;
  }

  static bool _isSpace(String char) => char.trim().isEmpty;
}
