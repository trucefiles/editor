import '../tree/blocks.dart';
import '../tree/inlines.dart';
import 'syntax/block_starts.dart';
import 'syntax/characters.dart';
import 'syntax/delimiter_runs.dart';
import 'syntax/extended_autolinks.dart';
import 'syntax/link_syntax.dart';

/// The inline content of [content] from [start] to [end], as CommonMark
/// and GitHub Flavored Markdown read it: emphasis, strikethrough, code,
/// links, images, autolinks (also GFM's bare ones), raw HTML, escapes,
/// character references and line breaks. Whitespace at its ends and the
/// content outside the range go to the result's `before` and `after`.
/// Reference links look up [definitions] by normalized label. In a
/// [tableCell], `\|` is a pipe also inside code. The one reader of inline
/// syntax.
InlineText readInlineText(
  String content, {
  int start = 0,
  int? end,
  Map<String, LinkDefinition> definitions = const {},
  bool tableCell = false,
}) {
  var from = start;
  var until = end ?? content.length;
  while (from < until && _isTrimmed(content[from])) {
    from++;
  }
  while (until > from && _isTrimmed(content[until - 1])) {
    until--;
  }
  return InlineText(
    content.substring(0, from),
    _InlineReader(content, from, until, definitions, tableCell).read(),
    content.substring(until),
  );
}

bool _isTrimmed(String char) => char == ' ' || char == '\t' || char == '\n';

enum _Kind {
  text,
  softBreak,
  hardBreak,
  code,
  html,
  emphasis,
  strong,
  strike,
  link,
  image,
}

/// A node while reading, with its range in the text.
final class _Node {
  _Node(this.kind, this.start, this.end, {this.literal = ''});

  final _Kind kind;
  int start;
  int end;
  String literal;
  _Node? parent;
  final children = <_Node>[];
  int innerStart = 0;
  int innerEnd = 0;
  String destination = '';
  String title = '';
  LinkStyle linkStyle = LinkStyle.inline;

  /// Whether a text node reads as its source.
  bool plain = false;

  void append(_Node child) {
    child.parent = this;
    children.add(child);
  }

  void unlink() {
    parent?.children.remove(this);
    parent = null;
  }

  Inline freeze(String text) {
    String slice(int from, int to) => text.substring(from, to);
    List<Inline> inner() => [for (final child in children) child.freeze(text)];
    String open() => slice(start, innerStart);
    String close() => slice(innerEnd, end);
    return switch (kind) {
      _Kind.text => TextInline(literal, slice(start, end)),
      _Kind.softBreak => SoftBreakInline(slice(start, end)),
      _Kind.hardBreak => HardBreakInline(slice(start, end)),
      _Kind.code => CodeInline(slice(start, end), literal),
      _Kind.html => HtmlInline(slice(start, end)),
      _Kind.emphasis => EmphasisInline(open(), inner(), close()),
      _Kind.strong => StrongInline(open(), inner(), close()),
      _Kind.strike => StrikeInline(open(), inner(), close()),
      _Kind.link => LinkInline(
        open(),
        inner(),
        close(),
        destination: destination,
        title: title,
        style: linkStyle,
      ),
      _Kind.image => ImageInline(
        open(),
        inner(),
        close(),
        destination: destination,
        title: title,
      ),
    };
  }
}

/// An emphasis or strikethrough delimiter run on the stack.
final class _Delimiter {
  _Delimiter(
    this.char,
    this.count,
    this.node, {
    required this.canOpen,
    required this.canClose,
  }) : original = count;

  final String char;
  int count;
  final int original;
  final _Node node;
  final bool canOpen;
  final bool canClose;
  _Delimiter? previous;
  _Delimiter? next;
}

/// A `[` or `![` on the stack.
final class _Bracket {
  _Bracket(
    this.node, {
    required this.index,
    required this.image,
    required this.previous,
    required this.previousDelimiter,
  });

  final _Node node;

  /// Where its label starts: at its `[`.
  final int index;
  final bool image;
  final _Bracket? previous;
  final _Delimiter? previousDelimiter;
  bool active = true;
  bool bracketAfter = false;
}

/// The reading state, as CommonMark's reference parser keeps it.
final class _InlineReader {
  _InlineReader(
    this._text,
    this._start,
    this._end,
    this._definitions,
    this._tableCell,
  ) : _pos = _start,
      _subject = _text.substring(0, _end);

  final String _text;

  /// [_text] up to [_end], for readers that look ahead.
  final String _subject;
  final int _start;
  final int _end;
  final Map<String, LinkDefinition> _definitions;
  final bool _tableCell;
  final _root = _Node(_Kind.text, 0, 0);
  int _pos;
  _Delimiter? _delimiters;
  _Bracket? _brackets;

  List<Inline> read() {
    while (_pos < _end) {
      _readInline();
    }
    _processEmphasis(null);
    _linkAutolinks(_root);
    return [for (final node in _root.children) node.freeze(_text)];
  }

  _Node _newText(int start, int end, {bool plain = true}) =>
      _Node(_Kind.text, start, end, literal: _text.substring(start, end))
        ..plain = plain;

  /// Joins runs of plain text in [node] and finds GFM's bare links in
  /// them, outside links and code.
  void _linkAutolinks(_Node node) {
    final joined = <_Node>[];
    for (final child in node.children) {
      final last = joined.isEmpty ? null : joined.last;
      if (child.kind == _Kind.text &&
          child.plain &&
          last != null &&
          last.kind == _Kind.text &&
          last.plain &&
          last.end == child.start) {
        last
          ..end = child.end
          ..literal = _text.substring(last.start, child.end);
      } else {
        joined.add(child);
      }
    }
    node.children
      ..clear()
      ..addAll([for (final child in joined) ..._linked(child)]);
    for (final child in node.children) {
      child.parent = node;
    }
  }

  List<_Node> _linked(_Node node) {
    switch (node.kind) {
      case _Kind.emphasis || _Kind.strong || _Kind.strike:
        _linkAutolinks(node);
        return [node];
      case _Kind.text when node.plain:
        break;
      case _:
        return [node];
    }
    final found = findExtendedAutolinks(_text, node.start, node.end);
    if (found.isEmpty) return [node];
    return [
      for (final (index, link) in found.indexed) ...[
        if (link.start > (index == 0 ? node.start : found[index - 1].end))
          _newText(index == 0 ? node.start : found[index - 1].end, link.start),
        _Node(_Kind.link, link.start, link.end)
          ..innerStart = link.start
          ..innerEnd = link.end
          ..destination = link.destination
          ..linkStyle = LinkStyle.extendedAutolink
          ..append(_newText(link.start, link.end)),
      ],
      if (found.last.end < node.end) _newText(found.last.end, node.end),
    ];
  }

  String _peek([int ahead = 0]) =>
      _pos + ahead < _end ? _text[_pos + ahead] : '';

  void _add(_Node node) => _root.append(node);

  void _addText(int start, int end, {String? literal}) => _add(
    _Node(
      _Kind.text,
      start,
      end,
      literal: literal ?? _text.substring(start, end),
    )..plain = literal == null,
  );

  void _readInline() {
    final char = _peek();
    final handled = switch (char) {
      '\n' => _readNewline(),
      r'\' => _readBackslash(),
      '`' => _readBackticks(),
      '*' || '_' || '~' => _readDelimiters(char),
      '[' => _readOpenBracket(),
      '!' => _readBang(),
      ']' => _readCloseBracket(),
      '<' => _readAutolink() || _readHtml(),
      '&' => _readEntity(),
      _ => _readString(),
    };
    if (!handled) {
      _addText(_pos, _pos + 1);
      _pos++;
    }
  }

  /// Skips the spaces and tabs at the start of a line.
  void _skipIndent() {
    while (_pos < _end && isSpaceOrTab(_text[_pos])) {
      _pos++;
    }
  }

  bool _readNewline() {
    final newline = _pos;
    _pos++;
    final last = _root.children.isEmpty ? null : _root.children.last;
    var breakStart = newline;
    var hard = false;
    if (last != null &&
        last.kind == _Kind.text &&
        last.plain &&
        last.literal.endsWith(' ')) {
      final trimmed = last.literal.replaceAll(_finalSpaces, '');
      hard = last.literal.length - trimmed.length >= 2;
      breakStart = last.end - (last.literal.length - trimmed.length);
      last
        ..literal = trimmed
        ..end = breakStart;
      if (trimmed.isEmpty) last.unlink();
    }
    _skipIndent();
    _add(_Node(hard ? _Kind.hardBreak : _Kind.softBreak, breakStart, _pos));
    return true;
  }

  bool _readBackslash() {
    final start = _pos;
    _pos++;
    final next = _peek();
    if (next == '\n') {
      _pos++;
      _skipIndent();
      _add(_Node(_Kind.hardBreak, start, _pos));
    } else if (isAsciiPunctuation(next)) {
      _pos++;
      _addText(start, _pos, literal: next);
    } else {
      _addText(start, _pos);
    }
    return true;
  }

  bool _readBackticks() {
    final start = _pos;
    while (_pos < _end && _text[_pos] == '`') {
      _pos++;
    }
    final ticks = _pos - start;
    final afterOpen = _pos;
    var at = _pos;
    while (at < _end) {
      if (_text[at] != '`') {
        at++;
        continue;
      }
      final runStart = at;
      while (at < _end && _text[at] == '`') {
        at++;
      }
      if (at - runStart == ticks) {
        final source = _text.substring(afterOpen, runStart);
        final contents = (_tableCell ? source.replaceAll(r'\|', '|') : source)
            .replaceAll('\n', ' ');
        final strip =
            contents.startsWith(' ') &&
            contents.endsWith(' ') &&
            contents.replaceAll(' ', '').isNotEmpty;
        _add(
          _Node(
            _Kind.code,
            start,
            at,
            literal: strip
                ? contents.substring(1, contents.length - 1)
                : contents,
          ),
        );
        _pos = at;
        return true;
      }
    }
    _addText(start, afterOpen);
    return true;
  }

  bool _readDelimiters(String char) {
    final start = _pos;
    while (_pos < _end && _text[_pos] == char) {
      _pos++;
    }
    final count = _pos - start;
    final (canOpen, canClose) = delimiterRunFlanks(
      char,
      count,
      before: start == _start ? '\n' : _text[start - 1],
      after: _pos >= _end ? '\n' : _text[_pos],
    );
    final node = _Node(_Kind.text, start, _pos, literal: char * count)
      ..plain = true;
    _add(node);
    if (canOpen || canClose) {
      final delimiter = _Delimiter(
        char,
        count,
        node,
        canOpen: canOpen,
        canClose: canClose,
      )..previous = _delimiters;
      _delimiters?.next = delimiter;
      _delimiters = delimiter;
    }
    return true;
  }

  void _removeDelimiter(_Delimiter delimiter) {
    delimiter.previous?.next = delimiter.next;
    if (delimiter.next == null) {
      _delimiters = delimiter.previous;
    } else {
      delimiter.next!.previous = delimiter.previous;
    }
  }

  void _processEmphasis(_Delimiter? bottom) {
    final openersBottom = <String, _Delimiter?>{};
    var closer = _delimiters;
    while (closer != null && closer.previous != bottom) {
      closer = closer.previous;
    }
    while (closer != null) {
      if (!closer.canClose) {
        closer = closer.next;
        continue;
      }
      final key = closer.char == '~'
          ? '~${closer.count}'
          : '${closer.char}${closer.canOpen ? 3 : 0}${closer.original % 3}';
      var opener = closer.previous;
      var found = false;
      while (opener != null &&
          opener != bottom &&
          opener != openersBottom[key]) {
        if (_matches(opener, closer)) {
          found = true;
          break;
        }
        opener = opener.previous;
      }
      final oldCloser = closer;
      if (found) {
        closer = _emphasize(opener!, closer);
      } else {
        openersBottom[key] = oldCloser.previous;
        if (!oldCloser.canOpen) _removeDelimiter(oldCloser);
        closer = closer.next;
      }
    }
    while (_delimiters != null && _delimiters != bottom) {
      _removeDelimiter(_delimiters!);
    }
  }

  static bool _matches(_Delimiter opener, _Delimiter closer) {
    if (opener.char != closer.char || !opener.canOpen) return false;
    if (closer.char == '~') return opener.count == closer.count;
    final odd =
        (closer.canOpen || opener.canClose) &&
        closer.original % 3 != 0 &&
        (opener.original + closer.original) % 3 == 0;
    return !odd;
  }

  /// Wraps the nodes between [opener] and [closer] in emphasis (or
  /// strikethrough) using as many of their delimiters as fit; returns the
  /// next closer to look at.
  _Delimiter? _emphasize(_Delimiter opener, _Delimiter closer) {
    final use = closer.char == '~'
        ? closer.count
        : (closer.count >= 2 && opener.count >= 2 ? 2 : 1);
    final openerNode = opener.node;
    final closerNode = closer.node;
    opener.count -= use;
    closer.count -= use;
    openerNode
      ..end -= use
      ..literal = openerNode.literal.substring(use);
    closerNode
      ..start += use
      ..literal = closerNode.literal.substring(use);
    final kind = closer.char == '~'
        ? _Kind.strike
        : (use == 1 ? _Kind.emphasis : _Kind.strong);
    final emphasis = _Node(kind, openerNode.end, closerNode.start)
      ..innerStart = openerNode.end + use
      ..innerEnd = closerNode.start - use;
    final siblings = openerNode.parent!.children;
    final from = siblings.indexOf(openerNode) + 1;
    final to = siblings.indexOf(closerNode);
    final moved = siblings.sublist(from, to);
    siblings.removeRange(from, to);
    moved.forEach(emphasis.append);
    emphasis.parent = openerNode.parent;
    siblings.insert(from, emphasis);
    for (var between = closer.previous; between != opener;) {
      final previous = between!.previous;
      _removeDelimiter(between);
      between = previous;
    }
    if (opener.count == 0) {
      openerNode.unlink();
      _removeDelimiter(opener);
    }
    if (closer.count == 0) {
      closerNode.unlink();
      final next = closer.next;
      _removeDelimiter(closer);
      return next;
    }
    return closer;
  }

  bool _readOpenBracket() {
    final start = _pos;
    _pos++;
    final node = _Node(_Kind.text, start, _pos, literal: '[')..plain = true;
    _add(node);
    _addBracket(node, index: start, image: false);
    return true;
  }

  bool _readBang() {
    final start = _pos;
    _pos++;
    if (_peek() != '[') {
      _addText(start, _pos);
      return true;
    }
    _pos++;
    final node = _Node(_Kind.text, start, _pos, literal: '![')..plain = true;
    _add(node);
    _addBracket(node, index: start + 1, image: true);
    return true;
  }

  void _addBracket(_Node node, {required int index, required bool image}) {
    _brackets?.bracketAfter = true;
    _brackets = _Bracket(
      node,
      index: index,
      image: image,
      previous: _brackets,
      previousDelimiter: _delimiters,
    );
  }

  bool _readCloseBracket() {
    final closeAt = _pos;
    _pos++;
    final afterClose = _pos;
    final opener = _brackets;
    if (opener == null) {
      _addText(closeAt, afterClose);
      return true;
    }
    if (!opener.active) {
      _addText(closeAt, afterClose);
      _brackets = opener.previous;
      return true;
    }
    final inline = _inlineTarget();
    final target = inline ?? _referenceTarget(opener, afterClose);
    if (target == null) {
      _brackets = opener.previous;
      _pos = afterClose;
      _addText(closeAt, afterClose);
      return true;
    }
    final link =
        _Node(opener.image ? _Kind.image : _Kind.link, opener.node.start, _pos)
          ..innerStart = opener.node.end
          ..innerEnd = closeAt
          ..destination = target.destination
          ..title = target.title ?? ''
          ..linkStyle = inline != null ? LinkStyle.inline : LinkStyle.reference;
    final siblings = _root.children;
    final from = siblings.indexOf(opener.node) + 1;
    final moved = siblings.sublist(from);
    siblings.removeRange(from, siblings.length);
    moved.forEach(link.append);
    _add(link);
    _processEmphasis(opener.previousDelimiter);
    _brackets = opener.previous;
    opener.node.unlink();
    if (!opener.image) {
      for (
        var earlier = _brackets;
        earlier != null;
        earlier = earlier.previous
      ) {
        if (!earlier.image) earlier.active = false;
      }
    }
    return true;
  }

  /// An inline link's `(destination "title")` right after a `]`.
  ({String destination, String? title})? _inlineTarget() {
    final save = _pos;
    if (_peek() != '(') return null;
    _pos++;
    _pos = skipSpaceAndNewline(_subject, _pos);
    final destination = readLinkDestination(_subject, _pos);
    if (destination == null) {
      _pos = save;
      return null;
    }
    _pos = destination.end;
    final beforeSpace = _pos;
    _pos = skipSpaceAndNewline(_subject, _pos);
    String? title;
    if (_pos > beforeSpace) {
      if (readLinkTitle(_subject, _pos) case final read?) {
        title = read.value;
        _pos = skipSpaceAndNewline(_subject, read.end);
      }
    }
    if (_peek() != ')') {
      _pos = save;
      return null;
    }
    _pos++;
    return (destination: destination.value, title: title);
  }

  /// A reference link's target: a full (`[text][label]`), collapsed
  /// (`[text][]`) or shortcut (`[text]`) reference to a definition.
  ({String destination, String? title})? _referenceTarget(
    _Bracket opener,
    int afterClose,
  ) {
    final label = _labelAt.matchAsPrefix(_subject, afterClose);
    final length = label == null || label[0]!.length > 1001
        ? 0
        : label[0]!.length;
    final String? raw = length > 2
        ? _subject.substring(afterClose + 1, afterClose + length - 1)
        : (opener.bracketAfter
              ? null
              : _subject.substring(opener.index + 1, afterClose - 1));
    final definition = raw == null ? null : _definitions[normalizeLabel(raw)];
    if (definition == null) return null;
    _pos = afterClose + length;
    return (destination: definition.destination, title: definition.title);
  }

  bool _readAutolink() {
    final rest = _text.substring(_pos, _end);
    if (_emailAutolink.matchAsPrefix(rest) case final match?) {
      return _addAutolink(match[0]!.length, 'mailto:${match[1]}');
    }
    if (_uriAutolink.matchAsPrefix(rest) case final match?) {
      return _addAutolink(match[0]!.length, match[1]!);
    }
    return false;
  }

  bool _addAutolink(int length, String destination) {
    final start = _pos;
    _pos += length;
    _add(
      _Node(_Kind.link, start, _pos)
        ..innerStart = start + 1
        ..innerEnd = _pos - 1
        ..destination = destination
        ..linkStyle = LinkStyle.autolink
        ..append(_newText(start + 1, _pos - 1, plain: false)),
    );
    return true;
  }

  bool _readHtml() {
    final match = _htmlTag.matchAsPrefix(_subject, _pos);
    if (match == null) return false;
    _add(_Node(_Kind.html, _pos, match.end));
    _pos = match.end;
    return true;
  }

  bool _readEntity() {
    final match = _entityHere.matchAsPrefix(_subject, _pos);
    if (match == null) return false;
    final decoded = decodeEntity(match[0]!);
    if (decoded == null) return false;
    _addText(_pos, match.end, literal: decoded);
    _pos = match.end;
    return true;
  }

  bool _readString() {
    final match = _main.matchAsPrefix(_subject, _pos);
    if (match == null) return false;
    _addText(_pos, match.end);
    _pos = match.end;
    return true;
  }
}

final _finalSpaces = RegExp(r' +$');
final _labelAt = RegExp(r'\[(?:[^\\\[\]]|\\.){0,1000}\]', dotAll: true);
final _main = RegExp(r'[^\n`\[\]\\!<&*_~]+');
final _entityHere = RegExp(
  r'&(?:#[xX][0-9a-fA-F]{1,6}|#[0-9]{1,7}|[A-Za-z][A-Za-z0-9]{1,31});',
);
final _emailAutolink = RegExp(
  r"<([a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)>",
);
final _uriAutolink = RegExp(
  r'<([A-Za-z][A-Za-z0-9.+-]{1,31}:[^<>\x00-\x20]*)>',
);
final _htmlTag = RegExp(
  '(?:$htmlOpenTag|$htmlClosingTag|<!-->|<!--->|<!--[\\s\\S]*?-->|'
  '[<][?][\\s\\S]*?[?][>]|<![A-Za-z][^>]*>|<!\\[CDATA\\[[\\s\\S]*?\\]\\]>)',
);
