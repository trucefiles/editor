import '../tree/blocks.dart';
import 'open_blocks.dart';
import 'syntax/block_starts.dart';
import 'syntax/characters.dart';
import 'syntax/link_syntax.dart';
import 'syntax/table_rows.dart';

/// Reads [lines] into open blocks, as CommonMark 0.31 and GitHub
/// Flavored Markdown do: in one pass from the top, each line first meets
/// the open containers, then may start new blocks, and the rest of it
/// goes to the innermost block that takes lines. Every line that is not
/// blank or an empty item's marker lands in exactly one leaf.
///
/// [lines] are the lines' texts, without their endings; front matter may
/// start them. The one reader of block structure.
OpenRoot readOpenBlocks(List<String> lines) => _Reader(lines).read();

const _codeIndent = 4;

/// The reading state, as CommonMark's reference parser keeps it.
final class _Reader {
  _Reader(this._lines);

  final List<String> _lines;
  late final OpenRoot _root;
  late OpenBlock _tip;
  late OpenBlock _oldTip;
  late OpenBlock _lastMatched;

  var _lineIndexNow = 0;
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
  var _segments = <Segment>[];

  OpenRoot read() {
    for (
      _lineIndexNow = _readFrontMatter();
      _lineIndexNow < _lines.length;
      _lineIndexNow++
    ) {
      _readLine();
    }
    _closeAll();
    return _root;
  }

  /// Front matter at the very top: a `---` line and a closing `---` or
  /// `...` line further down. Returns the index of the first line after
  /// it.
  int _readFrontMatter() {
    _root = OpenRoot();
    _tip = _root;
    _oldTip = _root;
    _lastMatched = _root;
    final first = _lines.firstOrNull;
    if (first == null || !frontMatterFence.hasMatch(first)) {
      return 0;
    }
    final end = _lines.indexWhere(frontMatterEnd.hasMatch, 1);
    if (end < 0) return 0;
    final front = OpenFrontMatter()
      ..open = false
      ..parent = _root;
    for (var index = 0; index <= end; index++) {
      front.lines.add(ReadLine(index, contentStart: 0, prefix: const []));
    }
    _root.children.add(front);
    return end + 1;
  }

  void _readLine() {
    _line = _lines[_lineIndexNow];
    _offset = 0;
    _column = 0;
    _blank = false;
    _partiallyConsumedTab = false;
    _segments = [];
    _oldTip = _tip;
    OpenBlock container = _root;
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
    var matchedLeaf = container is OpenLeaf && container.takesLines;
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
    if (!_allClosed && !_blank && _tip is OpenParagraph) {
      _addLine(_tip as OpenLeaf);
      return;
    }
    _closeUnmatched();
    switch (container) {
      case OpenLeaf() when container.takesLines:
        _addLine(container);
        if (container case OpenHtml(:final kind) when kind <= 5) {
          if (htmlBlockEnds[kind]!.hasMatch(_line.substring(_offset))) {
            _finalize(container, _lineIndexNow);
          }
        }
      case final OpenLeaf leaf when leaf is OpenParagraph || leaf is OpenTable:
        _addLine(leaf);
      case OpenContainer() when _offset < _line.length && !_blank:
        final paragraph = _addChild(OpenParagraph(_lineIndexNow)) as OpenLeaf;
        _advanceNextNonspace();
        _addLine(paragraph);
      case _:
        break;
    }
  }

  static OpenBlock? _lastOpenChild(OpenBlock block) => switch (block) {
    OpenContainer() => block.lastOpenChild,
    OpenLeaf() => null,
  };

  /// Whether the open [block] goes on in this line.
  _Continue _continues(OpenBlock block) => switch (block) {
    OpenRoot() || OpenList() => _Continue.matched,
    OpenQuote() => _continuesQuote(block),
    OpenItem() => _continuesItem(block),
    OpenCode() => _continuesCode(block),
    OpenHtml(:final kind) =>
      _blank && kind >= 6 ? _Continue.failed : _Continue.matched,
    OpenParagraph() ||
    OpenTable() => _blank ? _Continue.failed : _Continue.matched,
    OpenHeading() || OpenRule() || OpenFrontMatter() => _Continue.failed,
  };

  _Continue _continuesQuote(OpenQuote quote) {
    if (_indented || _charAt(_nextNonspace) != '>') return _Continue.failed;
    _consumeQuoteMark(quote);
    return _Continue.matched;
  }

  /// Takes a quote's `>` and the space after it for [quote].
  void _consumeQuoteMark(OpenContainer quote) {
    final start = _offset;
    final column = _column;
    _advanceNextNonspace();
    _advanceOffset(1, columns: false);
    if (isSpaceOrTab(_charAt(_offset))) _advanceOffset(1, columns: true);
    _segments.add((
      container: quote,
      start: start,
      end: _offset,
      columns: _column - column,
    ));
  }

  _Continue _continuesItem(OpenItem item) {
    final start = _offset;
    final column = _column;
    if (_blank) {
      if (item.isEmpty) return _Continue.failed;
      _advanceNextNonspace();
    } else if (_indent >= item.contentColumn) {
      _advanceOffset(item.contentColumn, columns: true);
    } else {
      return _Continue.failed;
    }
    _segments.add((
      container: item,
      start: start,
      end: _offset,
      columns: _column - column,
    ));
    return _Continue.matched;
  }

  _Continue _continuesCode(OpenCode code) {
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
    final fence = code.fence!;
    final rest = _line.substring(_nextNonspace);
    if (_indent <= 3 &&
        rest.startsWith(fence[0]) &&
        closesFence(rest, fence[0], fence.length)) {
      code.lines.add(
        ReadLine(_lineIndexNow, contentStart: _nextNonspace, prefix: _segments),
      );
      code.closed = true;
      _finalize(code, _lineIndexNow);
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
  bool? _startBlock(OpenBlock container) {
    final rest = _line.substring(_nextNonspace);
    if (!_indented && rest.startsWith('>')) {
      _closeUnmatched();
      final quote = _addChild(OpenQuote(_lineIndexNow)) as OpenQuote;
      _consumeQuoteMark(quote);
      return false;
    }
    if (!_indented) {
      if (atxHeading.matchAsPrefix(rest) case final marks?) {
        _closeUnmatched();
        _addLeafLine(
          OpenHeading(
            _lineIndexNow,
            level: marks[0]!.trim().length,
            style: HeadingStyle.atx,
          ),
        );
        return true;
      }
    }
    final fence = _indented ? null : codeFence.matchAsPrefix(rest);
    if (fence != null) {
      _closeUnmatched();
      _addChild(
        OpenCode.fenced(
          _lineIndexNow,
          fence: fence[0]!,
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
        _addChild(OpenHtml(_lineIndexNow, kind));
        return true;
      }
    }
    if (!_indented && container is OpenParagraph) {
      if (_startsTable(container, rest)) return true;
      if (_startsSetext(container, rest)) return true;
    }
    if (!_indented && thematicBreak.matchAsPrefix(rest) != null) {
      _closeUnmatched();
      _addLeafLine(OpenRule(_lineIndexNow));
      return true;
    }
    if ((!_indented || container is OpenList) && _startItem(container)) {
      return false;
    }
    if (_indented && _tip is! OpenParagraph && _tip is! OpenTable && !_blank) {
      _advanceOffset(_codeIndent, columns: true);
      _closeUnmatched();
      _addChild(OpenCode.indented(_lineIndexNow));
      return true;
    }
    return null;
  }

  /// The start condition of an HTML block [rest] opens inside
  /// [container]; condition 7 never interrupts a paragraph.
  int? _htmlKind(String rest, OpenBlock container) {
    final lazy = !_allClosed && !_blank && _tip is OpenParagraph;
    for (final MapEntry(key: kind, value: start) in htmlBlockStarts.entries) {
      if (start.matchAsPrefix(rest) == null) continue;
      if (kind < 7 || (container is! OpenParagraph && !lazy)) return kind;
    }
    return null;
  }

  /// A setext underline below the text of [paragraph]: the paragraph
  /// becomes a heading, unless only link definitions are in it.
  bool _startsSetext(OpenParagraph paragraph, String rest) {
    if (setextUnderline.matchAsPrefix(rest) == null) return false;
    _closeUnmatched();
    _readDefinitions(paragraph);
    final definitionLines = paragraph.definitionLines;
    if (definitionLines == paragraph.lines.length) return false;
    final parent = paragraph.parent!;
    final heading = OpenHeading(
      paragraph.lines[definitionLines].index,
      level: rest.startsWith('=') ? 1 : 2,
      style: HeadingStyle.setext,
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
  bool _startsTable(OpenParagraph paragraph, String rest) {
    final headerLine = paragraph.lines.last;
    final header = _lines[headerLine.index].substring(headerLine.contentStart);
    if (!startsTable(header, rest)) return false;
    final delimiters = splitTableRow(rest);
    _closeUnmatched();
    paragraph.lines.removeLast();
    final parent = paragraph.parent!;
    if (paragraph.lines.isEmpty) {
      parent.children.remove(paragraph);
    } else {
      _finalize(paragraph, headerLine.index - 1);
    }
    final table = OpenTable(headerLine.index, [
      for (final cell in delimiters) alignmentOf(cell.text),
    ])..parent = parent;
    parent.children.add(table);
    table.lines.add(headerLine);
    _tip = table;
    return true;
  }

  /// A list item's marker at the line's next non-space: starts the item,
  /// and a list for it if the open one is of another list.
  bool _startItem(OpenBlock container) {
    if (_indent >= 4) return false;
    final rest = _line.substring(_nextNonspace);
    final interrupts = container is OpenParagraph;
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
    if (interrupts && isBlankText(rest.substring(length))) return false;
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
    if (_tip is! OpenList || !(_tip as OpenList).marker.sameListAs(marker)) {
      _addChild(OpenList(_lineIndexNow, marker));
    }
    final item = _addChild(
      OpenItem(
        _lineIndexNow,
        marker: marker,
        markerOffset: markerOffset,
        padding: padding,
        checked: box == null ? null : box[1] != ' ',
      ),
    ) as OpenItem;
    if (box != null) {
      _offset = box.end;
      _column = columnsOf(_line.substring(0, _offset));
      _partiallyConsumedTab = false;
      if (isSpaceOrTab(_charAt(_offset))) _advanceOffset(1, columns: false);
    }
    _segments.add((
      container: item,
      start: start,
      end: _offset,
      columns: _column - startColumn,
    ));
    return true;
  }

  /// Adds [leaf] with the rest of the line from its next non-space, and
  /// ends it: a heading, rule or a setext heading's underline.
  void _addLeafLine(OpenLeaf leaf, {bool toTip = true}) {
    if (toTip) _addChild(leaf);
    leaf.lines.add(
      ReadLine(_lineIndexNow, contentStart: _nextNonspace, prefix: _segments),
    );
    _offset = _line.length;
    _finalize(leaf, _lineIndexNow);
  }

  /// Adds the rest of the line to [leaf].
  void _addLine(OpenLeaf leaf) {
    final tabColumns = _partiallyConsumedTab ? 4 - _column % 4 : 0;
    if (_partiallyConsumedTab) _offset++;
    final start = switch (leaf) {
      OpenCode(fenced: true, :final fenceStart, :final lines)
          when lines.isEmpty =>
        fenceStart,
      OpenParagraph() || OpenTable() => _nextNonspace,
      _ => _offset,
    };
    leaf.lines.add(
      ReadLine(
        _lineIndexNow,
        contentStart: start,
        prefix: _segments,
        tabColumns: leaf is OpenCode ? tabColumns : 0,
      ),
    );
  }

  OpenBlock _addChild(OpenBlock block) {
    while (!(_tip is OpenContainer &&
        (_tip as OpenContainer).canContain(block))) {
      _finalize(_tip, _lineIndexNow - 1);
    }
    final parent = _tip as OpenContainer;
    block.parent = parent;
    parent.children.add(block);
    _tip = block;
    return block;
  }

  void _closeUnmatched() {
    if (_allClosed) return;
    while (_oldTip != _lastMatched) {
      final parent = _oldTip.parent!;
      _finalize(_oldTip, _lineIndexNow - 1);
      _oldTip = parent;
    }
    _allClosed = true;
  }

  void _closeAll() {
    while (_tip != _root) {
      _finalize(_tip, _lines.length - 1);
    }
    _finalize(_root, _lines.length - 1);
  }

  void _finalize(OpenBlock block, int line) {
    block
      ..open = false
      ..lastLine = line < block.firstLine ? block.firstLine : line;
    switch (block) {
      case OpenParagraph():
        _readDefinitions(block);
      case OpenCode(fenced: false):
        _dropTrailingBlanks(block);
      case _:
        break;
    }
    if (_tip == block) _tip = block.parent ?? _root;
  }

  /// Reads the link reference definitions at the start of [paragraph].
  void _readDefinitions(OpenParagraph paragraph) {
    if (paragraph.definitionsRead) return;
    paragraph.definitionsRead = true;
    final text = paragraph.lines
        .map((line) => _lines[line.index].substring(line.contentStart))
        .join('\n');
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

  /// An indented code block ends at its last line that is not blank.
  void _dropTrailingBlanks(OpenCode code) {
    while (code.lines.length > 1 &&
        isBlankText(
          _lines[code.lines.last.index].substring(code.lines.last.contentStart),
        )) {
      code.lines.removeLast();
    }
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
