import 'package:collection/collection.dart';

import '../lines/markdown_line.dart';
import 'block_starts.dart';
import 'blocks.dart';
import 'characters.dart';
import 'link_syntax.dart';

/// Reads [lines] into the document's block tree, as CommonMark 0.31 and
/// GitHub Flavored Markdown do: in one pass from the top, each line first
/// meets the open containers, then may start new blocks, and the rest of
/// it goes to the innermost block that takes lines. Every line lands in
/// exactly one leaf. The one reader of block structure.
///
/// Two deviations, for typing: an empty list item interrupts a paragraph,
/// and a line of a single `-` below text is such an item, not a heading's
/// underline.
RootBlock readBlocks(List<MarkdownLine> lines) => _Reader(lines).read();

/// A container's part of one line, while reading.
typedef _Segment = ({_Box box, int start, int end, int columns});

/// A leaf's line, while reading.
final class _Line {
  _Line(
    this.index, {
    required this.contentStart,
    required this.prefix,
    this.virtualSpaces = 0,
  });

  final int index;
  final int contentStart;
  final List<_Segment> prefix;
  final int virtualSpaces;
}

/// A block while reading: open until finalized.
sealed class _Node {
  _Node(this.firstLine);

  _Box? parent;
  bool open = true;
  final int firstLine;

  /// The last line of its content, once finalized.
  late int lastLine;
}

/// A container while reading.
sealed class _Box extends _Node {
  _Box(super.firstLine);

  final children = <_Node>[];

  /// Blank lines in it.
  final blanks = <_Line>[];

  bool canContain(_Node child) => child is! _Item;
}

final class _Root extends _Box {
  _Root() : super(0);
}

final class _Quote extends _Box {
  _Quote(super.firstLine);
}

final class _List extends _Box {
  _List(super.firstLine, this.marker);

  final ItemMarker marker;

  @override
  bool canContain(_Node child) => child is _Item;
}

final class _Item extends _Box {
  _Item(
    super.firstLine, {
    required this.marker,
    required this.markerOffset,
    required this.padding,
    required this.checked,
  });

  final ItemMarker marker;
  final int markerOffset;
  final int padding;
  final bool? checked;

  int get contentColumn => markerOffset + padding;
}

/// A leaf while reading.
sealed class _Leaf extends _Node {
  _Leaf(super.firstLine);

  final lines = <_Line>[];

  /// Whether it takes the lines that reach it, unlike a paragraph, which
  /// new blocks may interrupt.
  bool get takesLines => false;
}

final class _Paragraph extends _Leaf {
  _Paragraph(super.firstLine);

  /// Link reference definitions at its start, read once it ends, and how
  /// many of its lines they take.
  List<LinkDefinition> definitions = const [];
  int definitionLines = 0;

  /// Its text, as the leaf's text reads.
  String text(List<MarkdownLine> lines) => this.lines
      .map((line) => _contentOf(lines[line.index].raw, line.contentStart))
      .join('\n');
}

final class _Heading extends _Leaf {
  _Heading(super.firstLine, {required this.level, required this.setext});

  final int level;
  final bool setext;
}

final class _Code extends _Leaf {
  _Code.fenced(
    super.firstLine, {
    required String this.fenceChar,
    required this.fenceLength,
    required this.fenceOffset,
    required this.fenceStart,
  });

  _Code.indented(super.firstLine)
    : fenceChar = null,
      fenceLength = 0,
      fenceOffset = 0,
      fenceStart = 0;

  final String? fenceChar;
  final int fenceLength;
  final int fenceOffset;

  /// Where the opening fence starts on its line.
  final int fenceStart;
  bool closed = false;

  bool get fenced => fenceChar != null;

  @override
  bool get takesLines => true;
}

final class _Html extends _Leaf {
  _Html(super.firstLine, this.kind);

  /// Its start condition, 1 to 7.
  final int kind;

  @override
  bool get takesLines => true;
}

final class _Table extends _Leaf {
  _Table(super.firstLine, this.alignments);

  final List<CellAlignment> alignments;
}

final class _Rule extends _Leaf {
  _Rule(super.firstLine);
}

final class _FrontMatter extends _Leaf {
  _FrontMatter() : super(0);
}

/// A line's text without a final carriage return, from [start] on.
String _contentOf(String raw, int start) {
  final end = raw.endsWith('\r') ? raw.length - 1 : raw.length;
  return start >= end ? '' : raw.substring(start, end);
}

const _codeIndent = 4;

/// The reading state, as CommonMark's reference parser keeps it.
final class _Reader {
  _Reader(this._lines);

  final List<MarkdownLine> _lines;
  final _root = _Root();
  late _Node _tip = _root;
  late _Node _oldTip = _root;
  late _Node _lastMatched = _root;

  var _lineIndex = 0;
  var _line = '';
  var _offset = 0;
  var _column = 0;
  var _nextNonspace = 0;
  var _nextNonspaceColumn = 0;
  var _indent = 0;
  var _indented = false;
  var _blank = false;
  var _partiallyConsumedTab = false;
  var _allClosed = true;
  var _segments = <_Segment>[];

  RootBlock read() {
    final start = _readFrontMatter();
    for (_lineIndex = start; _lineIndex < _lines.length; _lineIndex++) {
      _readLine(_lineIndex);
    }
    _lineIndex = _lines.length;
    while (_tip != _root) {
      _finalize(_tip, _lines.length - 1);
    }
    _finalize(_root, _lines.length - 1);
    return _Freezer(_lines).freeze(_root);
  }

  /// Front matter at the very top: a `---` line and a closing `---` or
  /// `...` line below it. Returns the index of the first line after it.
  int _readFrontMatter() {
    if (_lines.isEmpty || !frontMatterFence.hasMatch(_strip(_lines[0].raw))) {
      return 0;
    }
    final end = _lines.indexWhere(
      (line) => frontMatterEnd.hasMatch(_strip(line.raw)),
      1,
    );
    if (end < 0) return 0;
    final front = _FrontMatter();
    for (var index = 0; index <= end; index++) {
      front.lines.add(_Line(index, contentStart: 0, prefix: const []));
    }
    front
      ..open = false
      ..lastLine = end
      ..parent = _root;
    _root.children.add(front);
    return end + 1;
  }

  static String _strip(String raw) =>
      raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;

  void _readLine(int index) {
    _line = _strip(_lines[index].raw);
    _offset = 0;
    _column = 0;
    _blank = false;
    _partiallyConsumedTab = false;
    _segments = [];
    _oldTip = _tip;
    _Node container = _root;
    for (
      var child = _lastOpenChild(container);
      child != null;
      child = _lastOpenChild(container)
    ) {
      container = child;
      _findNextNonspace();
      switch (_continues(container)) {
        case _Continue.matched:
          continue;
        case _Continue.lineDone:
          return;
        case _Continue.failed:
          container = container.parent!;
      }
      break;
    }
    _allClosed = container == _oldTip;
    _lastMatched = container;
    var matchedLeaf = container is _Leaf && container.takesLines;
    while (!matchedLeaf) {
      _findNextNonspace();
      final started = _startBlock(container);
      if (started == null) {
        _advanceNextNonspace();
        break;
      }
      container = _tip;
      matchedLeaf = started;
    }
    if (!_allClosed && !_blank && _tip is _Paragraph) {
      _addLine(_tip as _Leaf);
      return;
    }
    _closeUnmatched();
    switch (container) {
      case _Leaf() when container.takesLines:
        _addLine(container);
        if (container case _Html(:final kind) when kind <= 5) {
          if (htmlBlockEnds[kind]!.hasMatch(_line.substring(_offset))) {
            _finalize(container, index);
          }
        }
      case final _Leaf leaf when leaf is _Paragraph || leaf is _Table:
        _addLine(leaf);
      case _Box() when _offset < _line.length && !_blank:
        final paragraph = _addChild(_Paragraph(index)) as _Paragraph;
        _advanceNextNonspace();
        _addLine(paragraph);
      case _Box() when _blank:
        _addBlank(container);
      case _:
        break;
    }
  }

  static _Node? _lastOpenChild(_Node node) => switch (node) {
    _Box(:final children) when children.isNotEmpty && children.last.open =>
      children.last,
    _ => null,
  };

  /// Whether the open [container] goes on in this line.
  _Continue _continues(_Node container) => switch (container) {
    _Root() || _List() => _Continue.matched,
    _Quote() => _continuesQuote(container),
    _Item() => _continuesItem(container),
    _Code() => _continuesCode(container),
    _Html(:final kind) =>
      _blank && kind >= 6 ? _Continue.failed : _Continue.matched,
    _Paragraph() || _Table() => _blank ? _Continue.failed : _Continue.matched,
    _Heading() || _Rule() || _FrontMatter() => _Continue.failed,
  };

  _Continue _continuesQuote(_Quote quote) {
    if (_indented || _charAt(_nextNonspace) != '>') return _Continue.failed;
    _consumeQuoteMark(quote);
    return _Continue.matched;
  }

  /// Takes a quote's `>` and the space after it for [quote].
  void _consumeQuoteMark(_Box quote) {
    final start = _offset;
    final column = _column;
    _advanceNextNonspace();
    _advanceOffset(1, columns: false);
    if (isSpaceOrTab(_charAt(_offset))) _advanceOffset(1, columns: true);
    _segments.add((
      box: quote,
      start: start,
      end: _offset,
      columns: _column - column,
    ));
  }

  _Continue _continuesItem(_Item item) {
    final start = _offset;
    final column = _column;
    if (_blank) {
      if (item.children.isEmpty) return _Continue.failed;
      _advanceNextNonspace();
    } else if (_indent >= item.contentColumn) {
      _advanceOffset(item.contentColumn, columns: true);
    } else {
      return _Continue.failed;
    }
    _segments.add((
      box: item,
      start: start,
      end: _offset,
      columns: _column - column,
    ));
    return _Continue.matched;
  }

  _Continue _continuesCode(_Code code) {
    if (!code.fenced) {
      if (_indent >= _codeIndent) {
        _advanceOffset(_codeIndent, columns: true);
      } else if (_blank) {
        _advanceNextNonspace();
      } else {
        return _Continue.failed;
      }
      return _Continue.matched;
    }
    final rest = _line.substring(_nextNonspace);
    if (_indent <= 3 &&
        rest.startsWith(code.fenceChar!) &&
        closesFence(rest, code.fenceChar!, code.fenceLength)) {
      code.lines.add(
        _Line(_lineIndex, contentStart: _nextNonspace, prefix: _segments),
      );
      code.closed = true;
      _finalize(code, _lineIndex);
      return _Continue.lineDone;
    }
    for (
      var skip = code.fenceOffset;
      skip > 0 && isSpaceOrTab(_charAt(_offset));
      skip--
    ) {
      _advanceOffset(1, columns: true);
    }
    return _Continue.matched;
  }

  /// Starts a block at the line's next non-space, inside [container], if
  /// the line opens one: returns whether that block is a leaf that takes
  /// the rest of the line; `null` if it opens none.
  bool? _startBlock(_Node container) {
    final rest = _line.substring(_nextNonspace);
    if (!_indented && rest.startsWith('>')) {
      _closeUnmatched();
      final quote = _addChild(_Quote(_lineIndex)) as _Quote;
      _consumeQuoteMark(quote);
      return false;
    }
    if (!_indented && atxHeading.matchAsPrefix(rest) != null) {
      _closeUnmatched();
      final level = atxHeading.matchAsPrefix(rest)![0]!.trim().length;
      _addLeafLine(_Heading(_lineIndex, level: level, setext: false));
      return true;
    }
    final fence = _indented ? null : codeFence.matchAsPrefix(rest);
    if (fence != null) {
      _closeUnmatched();
      _addChild(
        _Code.fenced(
          _lineIndex,
          fenceChar: fence[0]![0],
          fenceLength: fence[0]!.length,
          fenceOffset: _indent,
          fenceStart: _nextNonspace,
        ),
      );
      _advanceNextNonspace();
      _advanceOffset(fence[0]!.length, columns: false);
      return true;
    }
    if (!_indented && rest.startsWith('<')) {
      if (_htmlKind(rest, container) case final kind?) {
        _closeUnmatched();
        _addChild(_Html(_lineIndex, kind));
        return true;
      }
    }
    if (!_indented && container is _Paragraph) {
      if (_startsTable(container, rest)) return true;
      if (_startsSetext(container, rest)) return true;
    }
    if (!_indented && thematicBreak.matchAsPrefix(rest) != null) {
      _closeUnmatched();
      _addLeafLine(_Rule(_lineIndex));
      return true;
    }
    if ((!_indented || container is _List) && _startItem(container)) {
      return false;
    }
    if (_indented && _tip is! _Paragraph && _tip is! _Table && !_blank) {
      _advanceOffset(_codeIndent, columns: true);
      _closeUnmatched();
      _addChild(_Code.indented(_lineIndex));
      return true;
    }
    return null;
  }

  /// The start condition of an HTML block [rest] opens inside
  /// [container]; condition 7 never interrupts a paragraph.
  int? _htmlKind(String rest, _Node container) {
    final lazy = !_allClosed && !_blank && _tip is _Paragraph;
    for (final MapEntry(key: kind, value: start) in htmlBlockStarts.entries) {
      if (start.matchAsPrefix(rest) == null) continue;
      if (kind < 7 || (container is! _Paragraph && !lazy)) return kind;
    }
    return null;
  }

  /// A setext underline below the text of [paragraph]: the paragraph
  /// becomes a heading, unless only link definitions are in it. A single
  /// `-` is an empty item instead (see [readBlocks]).
  bool _startsSetext(_Paragraph paragraph, String rest) {
    if (setextUnderline.matchAsPrefix(rest) == null) return false;
    if (rest.trim() == '-') return false;
    _closeUnmatched();
    _readDefinitions(paragraph);
    final definitionLines = paragraph.definitionLines;
    if (definitionLines == paragraph.lines.length) return false;
    final parent = paragraph.parent!;
    final heading = _Heading(
      paragraph.lines[definitionLines].index,
      level: rest.startsWith('=') ? 1 : 2,
      setext: true,
    )..parent = parent;
    heading.lines.addAll(paragraph.lines.sublist(definitionLines));
    final siblings = parent.children;
    if (definitionLines == 0) {
      siblings[siblings.indexOf(paragraph)] = heading;
    } else {
      paragraph.lines.removeRange(definitionLines, paragraph.lines.length);
      _finalize(paragraph, paragraph.lines.last.index);
      siblings.add(heading);
    }
    _tip = heading;
    _addLeafLine(heading, toTip: false);
    return true;
  }

  /// A table's delimiter row below the last line of [paragraph], whose
  /// cells it matches: that line becomes the table's header.
  bool _startsTable(_Paragraph paragraph, String rest) {
    if (!tableDelimiterRow.hasMatch(rest)) return false;
    final headerLine = paragraph.lines.last;
    final header = _contentOf(
      _lines[headerLine.index].raw,
      headerLine.contentStart,
    );
    final delimiters = splitTableRow(rest);
    if (!header.contains('|') && !rest.contains('|')) return false;
    if (splitTableRow(header).length != delimiters.length) return false;
    _closeUnmatched();
    paragraph.lines.removeLast();
    final parent = paragraph.parent!;
    if (paragraph.lines.isEmpty) {
      parent.children.remove(paragraph);
    } else {
      _finalize(paragraph, headerLine.index - 1);
    }
    final table = _Table(headerLine.index, [
      for (final cell in delimiters) _alignmentOf(cell.text),
    ])..parent = parent;
    parent.children.add(table);
    table.lines.add(headerLine);
    _tip = table;
    return true;
  }

  static CellAlignment _alignmentOf(String delimiter) =>
      switch ((delimiter.startsWith(':'), delimiter.endsWith(':'))) {
        (true, true) => CellAlignment.center,
        (true, false) => CellAlignment.left,
        (false, true) => CellAlignment.right,
        (false, false) => CellAlignment.none,
      };

  /// A list item's marker at the line's next non-space: starts the item,
  /// and a list for it if the open one is of another list.
  bool _startItem(_Node container) {
    if (_indent >= 4) return false;
    final rest = _line.substring(_nextNonspace);
    final interrupts = container is _Paragraph;
    final ItemMarker marker;
    final int length;
    if (bulletMarker.matchAsPrefix(rest) case final match?) {
      marker = ItemMarker.bullet(match[0]!);
      length = 1;
    } else if (numberedMarker.matchAsPrefix(rest) case final match?
        when !interrupts || match[1] == '1') {
      marker = ItemMarker.numbered(int.parse(match[1]!), match[2]!);
      length = match[0]!.length;
    } else {
      return false;
    }
    final markerOffset = _indent;
    final start = _offset;
    final startColumn = _column;
    _advanceNextNonspace();
    _advanceOffset(length, columns: true);
    final spacesStartColumn = _column;
    final spacesStartOffset = _offset;
    do {
      _advanceOffset(1, columns: true);
    } while (_column - spacesStartColumn < 5 && isSpaceOrTab(_charAt(_offset)));
    final blankItem = _offset >= _line.length;
    final spaces = _column - spacesStartColumn;
    final int padding;
    if (spaces >= 5 || spaces < 1 || blankItem) {
      padding = length + 1;
      _column = spacesStartColumn;
      _offset = spacesStartOffset;
      _partiallyConsumedTab = false;
      if (isSpaceOrTab(_charAt(_offset))) _advanceOffset(1, columns: true);
    } else {
      padding = length + spaces;
    }
    final box = taskBox.matchAsPrefix(_line, _offset);
    _closeUnmatched();
    if (_tip is! _List || !(_tip as _List).marker.sameListAs(marker)) {
      _addChild(_List(_lineIndex, marker));
    }
    final item = _addChild(
      _Item(
        _lineIndex,
        marker: marker,
        markerOffset: markerOffset,
        padding: padding,
        checked: box == null ? null : box[1] != ' ',
      ),
    ) as _Item;
    if (box != null) {
      _offset = box.end;
      _column = columnsOf(_line.substring(0, _offset));
      _partiallyConsumedTab = false;
      if (isSpaceOrTab(_charAt(_offset))) _advanceOffset(1, columns: false);
    }
    _segments.add((
      box: item,
      start: start,
      end: _offset,
      columns: _column - startColumn,
    ));
    return true;
  }

  /// Adds [leaf] with the rest of the line from its next non-space, and
  /// ends it: a heading, rule or a setext heading's underline.
  void _addLeafLine(_Leaf leaf, {bool toTip = true}) {
    if (toTip) _addChild(leaf);
    leaf.lines.add(
      _Line(_lineIndex, contentStart: _nextNonspace, prefix: _segments),
    );
    _offset = _line.length;
    _finalize(leaf, _lineIndex);
  }

  /// Adds the rest of the line to [leaf].
  void _addLine(_Leaf leaf) {
    final virtualSpaces = _partiallyConsumedTab ? 4 - _column % 4 : 0;
    if (_partiallyConsumedTab) _offset++;
    final start = switch (leaf) {
      _Code(fenced: true, :final fenceStart, :final lines) when lines.isEmpty =>
        fenceStart,
      _Paragraph() || _Table() => _nextNonspace,
      _ => _offset,
    };
    leaf.lines.add(
      _Line(
        _lineIndex,
        contentStart: start,
        prefix: _segments,
        virtualSpaces: leaf is _Code ? virtualSpaces : 0,
      ),
    );
  }

  /// Puts this blank line in the deepest of the open containers up to
  /// [container] whose content its own indent and marks reach.
  void _addBlank(_Node container) {
    final chain = [
      for (_Node? node = container; node != null; node = node.parent) node,
    ].reversed.whereType<_Box>().toList();
    final reached = chain.takeWhile(_reaches).last;
    reached.blanks.add(
      _Line(
        _lineIndex,
        contentStart: _line.length,
        prefix: [
          for (final segment in _segments)
            if (chain.indexOf(segment.box) <= chain.indexOf(reached)) segment,
        ],
      ),
    );
  }

  /// Whether this line reaches into [box]: past a quote's `>`, or an
  /// item's content column.
  bool _reaches(_Box box) => switch (box) {
    _Root() || _List() => true,
    _Quote() => _segments.any((segment) => segment.box == box),
    _Item(:final contentColumn, :final firstLine) =>
      firstLine == _lineIndex ||
          _segments.any(
            (segment) => segment.box == box && segment.columns >= contentColumn,
          ),
  };

  _Node _addChild(_Node node) {
    while (!(_tip is _Box && (_tip as _Box).canContain(node))) {
      _finalize(_tip, _lineIndex - 1);
    }
    final parent = _tip as _Box;
    node.parent = parent;
    parent.children.add(node);
    _tip = node;
    return node;
  }

  void _closeUnmatched() {
    if (_allClosed) return;
    while (_oldTip != _lastMatched) {
      final parent = _oldTip.parent!;
      _finalize(_oldTip, _lineIndex - 1);
      _oldTip = parent;
    }
    _allClosed = true;
  }

  void _finalize(_Node node, int line) {
    node
      ..open = false
      ..lastLine = line;
    switch (node) {
      case _Paragraph():
        _readDefinitions(node);
      case _Code(fenced: false):
        _dropTrailingBlanks(node);
      case _Item(:final children) when children.isNotEmpty:
        node.lastLine = children.last.lastLine;
      case _Item():
        node.lastLine = node.firstLine;
      case _List(:final children):
        node.lastLine = children.last.lastLine;
      case _:
        break;
    }
    if (node.lastLine < node.firstLine) node.lastLine = node.firstLine;
    if (_tip == node) _tip = node.parent ?? _root;
  }

  /// Reads the link reference definitions at the start of [paragraph].
  void _readDefinitions(_Paragraph paragraph) {
    if (paragraph.definitionLines > 0) return;
    final text = paragraph.text(_lines);
    final definitions = <LinkDefinition>[];
    var at = 0;
    while (at < text.length && text[at] == '[') {
      final read = readLinkDefinition(text, at);
      if (read == null) break;
      definitions.add(read.value);
      at = read.end;
    }
    paragraph
      ..definitions = definitions
      ..definitionLines = at == 0
          ? 0
          : '\n'.allMatches(text.substring(0, at)).length +
                (at >= text.length && !text.endsWith('\n') ? 1 : 0);
  }

  /// An indented code block ends at its last line that is not blank; the
  /// blank lines after it are blank lines of its container.
  void _dropTrailingBlanks(_Code code) {
    final parent = code.parent!;
    while (code.lines.length > 1 &&
        isBlankText(_strip(_lines[code.lines.last.index].raw))) {
      final line = code.lines.removeLast();
      parent.blanks.add(
        _Line(
          line.index,
          contentStart: _lines[line.index].raw.length,
          prefix: line.prefix,
        ),
      );
    }
    code.lastLine = code.lines.last.index;
  }

  String _charAt(int index) => index < _line.length ? _line[index] : '';

  void _findNextNonspace() {
    var index = _offset;
    var columns = _column;
    while (index < _line.length) {
      final char = _line[index];
      if (char == ' ') {
        columns++;
      } else if (char == '\t') {
        columns += 4 - columns % 4;
      } else {
        break;
      }
      index++;
    }
    _blank = index >= _line.length;
    _nextNonspace = index;
    _nextNonspaceColumn = columns;
    _indent = _nextNonspaceColumn - _column;
    _indented = _indent >= _codeIndent;
  }

  void _advanceNextNonspace() {
    _offset = _nextNonspace;
    _column = _nextNonspaceColumn;
    _partiallyConsumedTab = false;
  }

  void _advanceOffset(int count, {required bool columns}) {
    var left = count;
    while (left > 0 && _offset < _line.length) {
      if (_line[_offset] == '\t') {
        final toTab = 4 - _column % 4;
        if (columns) {
          _partiallyConsumedTab = toTab > left;
          final advance = toTab > left ? left : toTab;
          _column += advance;
          if (!_partiallyConsumedTab) _offset++;
          left -= advance;
        } else {
          _partiallyConsumedTab = false;
          _column += toTab;
          _offset++;
          left--;
        }
      } else {
        _partiallyConsumedTab = false;
        _offset++;
        _column++;
        left--;
      }
    }
  }
}

enum _Continue { matched, failed, lineDone }

/// A table row's cells: split at unescaped pipes, outer pipes dropped,
/// each with where its text starts and ends in [row].
List<({String text, int start, int end})> splitTableRow(String row) {
  final cells = <({String text, int start, int end})>[];
  var start = 0;
  var end = row.length;
  final leading = row.length - row.trimLeft().length;
  final trailing = row.trimRight().length;
  if (leading < trailing && row[leading] == '|') start = leading + 1;
  if (trailing > start &&
      row[trailing - 1] == '|' &&
      (trailing < 2 || row[trailing - 2] != r'\')) {
    end = trailing - 1;
  }
  var cellStart = start;
  for (var index = start; index <= end; index++) {
    final atEnd = index == end;
    if (!atEnd && row[index] == r'\') {
      index++;
      continue;
    }
    if (atEnd || row[index] == '|') {
      final raw = row.substring(cellStart, index);
      final textStart = cellStart + raw.length - raw.trimLeft().length;
      final textEnd = cellStart + raw.trimRight().length;
      cells.add((
        text: row.substring(
          textStart,
          textEnd < textStart ? textStart : textEnd,
        ),
        start: textStart,
        end: textEnd < textStart ? textStart : textEnd,
      ));
      cellStart = index + 1;
    }
  }
  return cells;
}

/// Turns the blocks read into the immutable tree.
final class _Freezer {
  _Freezer(this._lines);

  final List<MarkdownLine> _lines;
  final _containers = <_Box, ContainerBlock>{};

  RootBlock freeze(_Root root) => _container(root) as RootBlock;

  /// The block of [box], with the blank lines in it and [spanned]: blank
  /// lines its parent took that lie between its own lines.
  ContainerBlock _container(_Box box, [List<_Line> spanned = const []]) {
    final block = switch (box) {
      _Root() => RootBlock(),
      _Quote() => QuoteBlock(),
      _List() => ListBlock(tight: _isTight(box)),
      _Item() => ItemBlock(
        markerLine: _lines[box.firstLine].id,
        marker: box.marker,
        checked: box.checked,
        markerColumn: box.markerOffset,
        contentColumn: box.contentColumn,
      ),
    };
    _containers[box] = block;
    // Each blank line goes before the first child that ends after it, or
    // into that child if it starts before it, so leaves stay in file order.
    final byChild = groupBy(
      [...box.blanks, ...spanned]..sort((a, b) => a.index - b.index),
      (blank) => box.children.indexWhere((child) => _end(child) >= blank.index),
    );
    bool within(_Line blank, _Node child) =>
        child is _Box && child.firstLine < blank.index;
    block.adopt([
      for (final (index, child) in box.children.indexed) ...[
        for (final blank in byChild[index] ?? const <_Line>[])
          if (!within(blank, child)) BlankBlock([_leafLine(blank)]),
        ..._blocks(child, [
          for (final blank in byChild[index] ?? const <_Line>[])
            if (within(blank, child)) blank,
        ]),
      ],
      for (final blank in byChild[-1] ?? const <_Line>[])
        BlankBlock([_leafLine(blank)]),
    ]);
    return block;
  }

  /// The last line in [node], its blank lines included.
  static int _end(_Node node) => switch (node) {
    _Box(:final children, :final blanks) => [
      node.lastLine,
      ...blanks.map((blank) => blank.index),
      ...children.map(_end),
    ].max,
    _Leaf() => node.lastLine,
  };

  List<MarkdownBlock> _blocks(_Node node, List<_Line> spanned) =>
      switch (node) {
        _Box() => [_container(node, spanned)],
        _Paragraph() => _paragraph(node),
        _Heading() => [_heading(node)],
        _Code() => [
          CodeBlock(
            _leafLines(node.lines),
            fenced: node.fenced,
            closed: node.closed,
            info: node.fenced ? _infoOf(node) : '',
          ),
        ],
        _Html() => [HtmlBlock(_leafLines(node.lines))],
        _Table() => [_table(node)],
        _Rule() => [RuleBlock(_leafLines(node.lines))],
        _FrontMatter() => [FrontMatterBlock(_leafLines(node.lines))],
      };

  List<MarkdownBlock> _paragraph(_Paragraph paragraph) {
    final lines = _leafLines(paragraph.lines);
    final split = paragraph.definitionLines.clamp(0, lines.length);
    return [
      if (split > 0)
        DefinitionsBlock(lines.sublist(0, split), paragraph.definitions),
      if (split < lines.length) ParagraphBlock(lines.sublist(split)),
    ];
  }

  HeadingBlock _heading(_Heading heading) {
    final lines = _leafLines(heading.lines);
    final texts = [for (final line in lines) line.content];
    final (start, end) = heading.setext
        ? (0, texts.take(texts.length - 1).join('\n').length)
        : _atxText(texts.single);
    return HeadingBlock(
      lines,
      level: heading.level,
      setext: heading.setext,
      textStart: start,
      textEnd: end < start ? start : end,
    );
  }

  /// Where an ATX heading's text starts and ends in [text]: after its
  /// `#` marks and spaces, before a closing run of `#`.
  static (int, int) _atxText(String text) {
    final open = atxHeading.matchAsPrefix(text)!.end;
    final rest = text.substring(open);
    final closing = RegExp(r'(?:^|[ \t]+)#+[ \t]*$').firstMatch(rest);
    final trimmed = closing == null ? rest : rest.substring(0, closing.start);
    final end = open + trimmed.trimRight().length;
    return (open, end);
  }

  TableBlock _table(_Table table) {
    final lines = _leafLines(table.lines);
    final width = table.alignments.length;
    List<TableCell?> cellsOf(String row) {
      final cells = splitTableRow(row);
      return [
        for (var column = 0; column < width; column++)
          column < cells.length
              ? (start: cells[column].start, end: cells[column].end)
              : null,
      ];
    }

    return TableBlock(
      lines,
      alignments: table.alignments,
      cells: [
        for (final (index, line) in lines.indexed)
          if (index != 1) cellsOf(line.content),
      ],
    );
  }

  String _infoOf(_Code code) {
    final first = code.lines.first;
    final raw = _contentOf(_lines[first.index].raw, first.contentStart);
    return unescapeText(raw.substring(code.fenceLength).trim());
  }

  bool _isTight(_List list) {
    bool endsWithBlank(_Node node, _Node? next) =>
        next != null && node.lastLine < next.firstLine - 1;
    final items = list.children;
    for (final (index, item) in items.indexed) {
      final next = index + 1 < items.length ? items[index + 1] : null;
      if (endsWithBlank(item, next)) return false;
      final children = (item as _Box).children;
      for (final (childIndex, child) in children.indexed) {
        final after = childIndex + 1 < children.length
            ? children[childIndex + 1]
            : null;
        if (endsWithBlank(child, after)) return false;
      }
    }
    return true;
  }

  List<LeafLine> _leafLines(List<_Line> lines) => [
    for (final line in lines) _leafLine(line),
  ];

  LeafLine _leafLine(_Line line) => LeafLine(
    _lines[line.index],
    contentStart: line.contentStart.clamp(0, _lines[line.index].raw.length),
    prefix: _prefix(line.prefix),
    virtualSpaces: line.virtualSpaces,
  );

  List<PrefixSegment> _prefix(List<_Segment> segments) => [
    for (final segment in segments)
      (
        container: _containers[segment.box]!,
        start: segment.start,
        end: segment.end,
      ),
  ];
}
