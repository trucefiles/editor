import 'dart:math';

/// A Markdown document seen as lines, e.g. checkbox items, headings and
/// text.
///
/// Every edit is a plain line edit: lines that are not touched stay
/// byte-identical, and non-checkbox lines (headings, text) stay in place.
/// Immutable; each edit returns a new [MarkdownLines].
///
/// Every line has an [MarkdownLine.id] that survives edits, so a UI can
/// follow a line while its text changes. Ids are only unique within the
/// documents derived from one [MarkdownLines.parse].
final class MarkdownLines {
  const MarkdownLines._(this.lines, this._indentUnit, this._nextId);

  /// Parses [text] with `\n` line breaks.
  factory MarkdownLines.parse(String text) => MarkdownLines._parseFrom(text, 0);

  factory MarkdownLines._parseFrom(String text, int firstId) {
    final lines = <MarkdownLine>[];
    for (final raw in text.split('\n')) {
      lines.add(MarkdownLine._parse(firstId + lines.length, raw));
    }
    return MarkdownLines._(lines, _detectIndentUnit(lines), firstId + lines.length);
  }

  /// Parses [text] as a whole new document, e.g. after it changed
  /// elsewhere. Its ids never repeat this document's ids, so a UI cannot
  /// mistake a new line for an old one.
  MarkdownLines reparse(String text) => MarkdownLines._parseFrom(text, _nextId);

  /// All lines, in file order.
  final List<MarkdownLine> lines;

  /// One indent level as written in this file: two spaces unless the
  /// file already uses another indent.
  final String _indentUnit;

  final int _nextId;

  /// Whether the document has checkbox items, i.e. a checklist view fits.
  bool get hasItems => lines.any((line) => line.isItem);

  String get text => lines.map((line) => line.raw).join('\n');

  /// Ids of checked items and of every line below them (their subitems),
  /// which a UI shows as done together.
  Set<int> get doneIds {
    final ids = <int>{};
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].isChecked) continue;
      final end = _blockEnd(i);
      for (; i < end; i++) {
        ids.add(lines[i].id);
      }
      i--;
    }
    return ids;
  }

  /// Nesting level of [line]: 0 at the left margin.
  int depthOf(MarkdownLine line) => _width(line.indent) ~/ _width(_indentUnit);

  MarkdownLines toggle(int id) => _replaceLine(id, (line) => line._toggled());

  /// Toggles the item [id] and, at the left margin, moves it with its
  /// subitems within its own list: once checked, below the list's last
  /// item; once unchecked, below its last open item at the margin, or
  /// above its first item if none is open. A list ends at a line at the
  /// margin that is neither an item nor blank, e.g. a heading. A subitem
  /// toggles in place, under its item. Then every other checked item at
  /// the margin moves below too (see [sortChecked]), e.g. ones another
  /// editor left among the open items. Lines other than items stay in
  /// place, and an item with only such lines between it and its place
  /// does not move.
  MarkdownLines toggleAndSort(int id) => toggle(id)._sorted(id).sortChecked();

  /// Moves every checked item at the left margin, with its subitems, below
  /// the last item of its list, keeping their order; as [toggleAndSort]
  /// does for one.
  MarkdownLines sortChecked() => [
    for (final line in lines)
      if (line.isChecked && line.indent.isEmpty) line.id,
  ].fold(this, (list, id) => list._sorted(id));

  /// The item [id] moved to where [toggleAndSort] puts it.
  MarkdownLines _sorted(int id) {
    final index = _indexOf(id);
    if (lines[index].indent.isNotEmpty) return this;
    final target = _sortTarget(index);
    if (target == null) return this;
    final end = _blockEnd(index);
    final between = target < index
        ? lines.sublist(target, index)
        : lines.sublist(end, max(end, target));
    if (!between.any((line) => line.isItem)) return this;
    return move(id, beforeId: target < lines.length ? lines[target].id : null);
  }

  /// Where [_sorted] puts the margin item at [index]: the index of
  /// the line to go before (the length for the end); `null` if its list
  /// has no other item to sort against.
  int? _sortTarget(int index) {
    final end = _blockEnd(index);
    final (first, last) = _listAround(index);
    final others = [
      for (var i = first; i < last; i++)
        if ((i < index || i >= end) &&
            lines[i].isItem &&
            lines[i].indent.isEmpty)
          i,
    ];
    if (others.isEmpty) return null;
    if (lines[index].isChecked) return _blockEnd(others.last);
    final open = others.where((i) => !lines[i].isChecked);
    return open.isEmpty ? others.first : _blockEnd(open.last);
  }

  /// The list the line at [index] is in: from its first line to past its
  /// last, up to the lines at the margin that are neither items nor blank.
  (int, int) _listAround(int index) {
    bool ends(MarkdownLine line) =>
        !line.isItem && line.indent.isEmpty && line.raw.trim().isNotEmpty;
    var first = index;
    while (first > 0 && !ends(lines[first - 1])) {
      first--;
    }
    var last = index + 1;
    while (last < lines.length && !ends(lines[last])) {
      last++;
    }
    return (first, last);
  }

  MarkdownLines setText(int id, String text) =>
      _replaceLine(id, (line) => line._withText(text));

  /// Adds an unchecked item after the item [afterId] and its subitems, at
  /// the same level. Returns the new document and the new line's id.
  (MarkdownLines, int) insertAfter(int afterId, String text) {
    final index = _indexOf(afterId);
    final line = lines[index];
    return _insert(_blockEnd(index), line._newSibling(_nextId, text));
  }

  /// Adds an unchecked item at the left margin after the last item, or at
  /// the end if there are none; an empty document gets it as its first
  /// line. Returns the new document and the new line's id.
  (MarkdownLines, int) append(String text) {
    final lastItem = lines.lastIndexWhere((line) => line.isItem);
    if (lastItem >= 0) {
      final sibling = lines[lastItem]._newSibling(_nextId, text);
      return _insert(_blockEnd(lastItem), sibling._withIndent(''));
    }
    final item = MarkdownLine._parse(
      _nextId,
      '- [ ] ${MarkdownLine._oneLine(text)}',
    );
    if (this.text.isEmpty) return _insert(0, item);
    final trailingEmpty = lines.length > 1 && lines.last.raw.isEmpty;
    return _insert(trailingEmpty ? lines.length - 1 : lines.length, item);
  }

  /// Adds an unchecked item at the left margin after the item [afterId]
  /// and its subitems; for a subitem, after the item at the margin it is
  /// under, so the new item never takes subitems of another. Returns the
  /// new document and the new line's id.
  (MarkdownLines, int) appendAfter(int afterId, String text) {
    final top = _marginItemOf(_indexOf(afterId));
    final sibling = lines[top]._newSibling(_nextId, text)._withIndent('');
    return _insert(_blockEnd(top), sibling);
  }

  /// Adds an unchecked item just before the item [beforeId], at its level,
  /// so the items below never become its subitems. Returns the new
  /// document and the new line's id.
  (MarkdownLines, int) insertBefore(int beforeId, String text) {
    final index = _indexOf(beforeId);
    return _insert(index, lines[index]._newSibling(_nextId, text));
  }

  /// Appends the text of the item [id] to the item [into] and removes the
  /// line of [id], as joining two lines in a text editor. Lines below it
  /// (its subitems) stay where they are.
  MarkdownLines join(int id, {required int into}) {
    final text = lines[_indexOf(id)].text;
    return _replaceLine(
      into,
      (line) => line._withText(line.text + text),
    ).removeLine(id);
  }

  /// Removes only the line of [id]; lines below it (its subitems) stay
  /// where they are, as deleting an empty line in a text editor.
  MarkdownLines removeLine(int id) {
    return _with([...lines]..removeAt(_indexOf(id)));
  }

  /// Removes the item [id] with its subitems.
  MarkdownLines remove(int id) {
    final index = _indexOf(id);
    return _with([...lines]..removeRange(index, _blockEnd(index)));
  }

  /// Moves the item [id] with its subitems to just before the line
  /// [beforeId], or to the end if [beforeId] is `null`. Levels are kept.
  MarkdownLines move(int id, {required int? beforeId}) {
    final start = _indexOf(id);
    final end = _blockEnd(start);
    final block = lines.sublist(start, end);
    if (block.any((line) => line.id == beforeId)) return this;
    final rest = [...lines]..removeRange(start, end);
    final trailingEmpty = rest.length > 1 && rest.last.raw.isEmpty;
    final target = beforeId == null
        ? (trailingEmpty ? rest.length - 1 : rest.length)
        : rest.indexWhere((line) => line.id == beforeId);
    return _with(rest..insertAll(target, block));
  }

  /// Moves the item [id] with its subitems one level right, under the
  /// line shown above it. Lines in [hidden] (e.g. done items a UI shows
  /// elsewhere) and empty lines are not shown; hidden lines in between
  /// move below the item, so it lands under the line the user saw.
  ///
  /// Does nothing if the line shown above is not an item, or if the item
  /// is already one level deeper than it.
  MarkdownLines indent(int id, {Set<int> hidden = const {}}) {
    final index = _indexOf(id);
    final above = _shownAbove(index, hidden);
    if (above == null || !lines[above].isItem) return this;
    if (depthOf(lines[index]) > depthOf(lines[above])) return this;
    final aboveEnd = _blockEnd(above);
    final placed = aboveEnd < index
        ? move(id, beforeId: lines[aboveEnd].id)
        : this;
    return placed._reindentBlock(
      placed._indexOf(id),
      (indent) => '$indent$_indentUnit',
    );
  }

  /// Moves the item [id] with its subitems one level left. Does nothing at
  /// the left margin.
  MarkdownLines outdent(int id) {
    final index = _indexOf(id);
    final indent = lines[index].indent;
    if (indent.isEmpty) return this;
    final cut = indent.endsWith(_indentUnit)
        ? _indentUnit.length
        : (indent.endsWith('\t') ? 1 : indent.length);
    // A subitem indented with other characters (a tab under spaces) may be
    // shorter than the cut; it then moves to the margin.
    return _reindentBlock(
      index,
      (lineIndent) => lineIndent.substring(0, max(0, lineIndent.length - cut)),
    );
  }

  /// Removes all checked items, with their subitems.
  MarkdownLines clearDone() {
    final done = doneIds;
    return _with(lines.where((line) => !done.contains(line.id)).toList());
  }

  /// Index of the nearest line above [index] that is neither empty nor
  /// in [hidden]; `null` if there is none.
  int? _shownAbove(int index, Set<int> hidden) {
    for (var i = index - 1; i >= 0; i--) {
      if (lines[i].raw.trim().isNotEmpty && !hidden.contains(lines[i].id)) {
        return i;
      }
    }
    return null;
  }

  /// Index of the item at the left margin that the item at [index] is
  /// under: the nearest less indented item above, up to the margin, within
  /// its run of items. [index] itself if it is at the margin.
  int _marginItemOf(int index) {
    var top = index;
    for (var i = index - 1; i >= 0 && _width(lines[top].indent) > 0; i--) {
      if (!lines[i].isItem) break;
      if (_width(lines[i].indent) < _width(lines[top].indent)) top = i;
    }
    return top;
  }

  /// Index just past [index]'s block: the line and every following line
  /// indented deeper than it. An empty line ends a block.
  int _blockEnd(int index) {
    final width = _width(lines[index].indent);
    var end = index + 1;
    while (end < lines.length &&
        lines[end].raw.trim().isNotEmpty &&
        _width(lines[end].indent) > width) {
      end++;
    }
    return end;
  }

  MarkdownLines _reindentBlock(int index, String Function(String) change) {
    final end = _blockEnd(index);
    return _with([
      for (var i = 0; i < lines.length; i++)
        i >= index && i < end
            ? lines[i]._withIndent(change(lines[i].indent))
            : lines[i],
    ]);
  }

  (MarkdownLines, int) _insert(int index, MarkdownLine line) => (
    MarkdownLines._([...lines]..insert(index, line), _indentUnit, _nextId + 1),
    line.id,
  );

  MarkdownLines _replaceLine(int id, MarkdownLine Function(MarkdownLine) f) {
    final index = _indexOf(id);
    return _with([...lines]..[index] = f(lines[index]));
  }

  MarkdownLines _with(List<MarkdownLine> lines) =>
      MarkdownLines._(lines, _indentUnit, _nextId);

  int _indexOf(int id) {
    final index = lines.indexWhere((line) => line.id == id);
    if (index < 0) throw ArgumentError.value(id, 'id', 'no such line');
    return index;
  }

  static String _detectIndentUnit(List<MarkdownLine> lines) {
    String? unit;
    for (final line in lines) {
      if (!line.isItem || line.indent.isEmpty) continue;
      if (unit == null || _width(line.indent) < _width(unit)) {
        unit = line.indent;
      }
    }
    return unit ?? '  ';
  }

  /// Visual width of leading whitespace; a tab counts as four spaces.
  static int _width(String indent) =>
      indent.runes.fold(0, (sum, rune) => sum + (rune == 0x09 ? 4 : 1));
}

/// One line of [MarkdownLines]: a checkbox item or any other line.
final class MarkdownLine {
  const MarkdownLine._(this.id, this.raw, this._item);

  factory MarkdownLine._parse(int id, String raw) {
    final match = _itemPattern.firstMatch(raw);
    return MarkdownLine._(
      id,
      raw,
      match == null
          ? null
          : _ItemParts(
              indentEnd: match.group(1)!.length,
              markIndex: match.group(1)!.length + match.group(2)!.length + 1,
              textStart: raw.length - match.group(3)!.length,
            ),
    );
  }

  /// `- [ ] text`, also with `*` or `+` bullets and `[x]` or `[X]`; as in
  /// GitHub Flavored Markdown, the box is followed by whitespace or the end
  /// of the line, so `- [x](url)` is a bulleted link, not an item.
  static final _itemPattern = RegExp(
    r'^([ \t]*)([-*+][ \t]+)\[[ xX]\](?:[ \t]|$)(.*)$',
  );

  final int id;

  /// The line as in the file, without its line break.
  final String raw;

  final _ItemParts? _item;

  bool get isItem => _item != null;

  bool get isChecked => switch (_item) {
    final item? => raw[item.markIndex] != ' ',
    null => false,
  };

  /// The item's text after the checkbox; the whole line for other lines.
  String get text => switch (_item) {
    final item? => raw.substring(item.textStart),
    null => raw,
  };

  /// Leading whitespace.
  String get indent => switch (_item) {
    final item? => raw.substring(0, item.indentEnd),
    null => raw.substring(0, raw.length - raw.trimLeft().length),
  };

  MarkdownLine _toggled() {
    final item = _item!;
    final mark = isChecked ? ' ' : 'x';
    return MarkdownLine._(
      id,
      raw.replaceRange(item.markIndex, item.markIndex + 1, mark),
      item,
    );
  }

  /// Keeps the prefix as written; a box at the end of the line gets a
  /// space before its first text.
  MarkdownLine _withText(String text) {
    final item = _item!;
    var prefix = raw.substring(0, item.textStart);
    if (text.isNotEmpty && prefix.endsWith(']')) prefix = '$prefix ';
    return MarkdownLine._parse(id, '$prefix${_oneLine(text)}');
  }

  MarkdownLine _withIndent(String indent) =>
      MarkdownLine._parse(id, '$indent${raw.substring(this.indent.length)}');

  /// An unchecked item at this line's level, with its bullet style.
  MarkdownLine _newSibling(int id, String text) {
    final item = _item!;
    final prefix = raw.substring(0, item.markIndex - 1);
    return MarkdownLine._parse(id, '$prefix[ ] ${_oneLine(text)}');
  }

  /// [text] with line breaks as spaces: an item is one line, and pasted
  /// text can hold breaks (`\r`, U+2028) that a text field lets through.
  static String _oneLine(String text) => text.replaceAll(_lineBreaks, ' ');

  static final _lineBreaks = RegExp('\r\n|[\r\n\u2028\u2029]');
}

final class _ItemParts {
  const _ItemParts({
    required this.indentEnd,
    required this.markIndex,
    required this.textStart,
  });

  /// End of leading whitespace.
  final int indentEnd;

  /// Index of the character between `[` and `]`.
  final int markIndex;

  /// Start of the item text.
  final int textStart;
}
