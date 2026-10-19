import 'dart:math';

import 'block.dart';
import 'line_id.dart';
import 'markdown_line.dart';
import 'syntax/line_kinds.dart';

/// A Markdown document seen as lines, e.g. list items, headings and text.
///
/// Every edit is a plain line edit: lines that are not touched stay
/// byte-identical, and lines other than list items (headings, text) stay
/// in place.
/// Immutable; each edit returns a new [MarkdownLines].
///
/// Every line has an [MarkdownLine.id] that survives edits, so a UI can
/// follow a line while its text changes. Ids are only unique within the
/// documents derived from one [MarkdownLines.parse].
final class MarkdownLines {
  MarkdownLines._(this.lines, this._indentUnit, this._nextId);

  /// Parses [text] with `\n` line breaks.
  factory MarkdownLines.parse(String text) => MarkdownLines._parseFrom(text, 0);

  factory MarkdownLines._parseFrom(String text, int firstId) {
    final lines = <MarkdownLine>[];
    for (final raw in text.split('\n')) {
      lines.add(MarkdownLine.parse(LineId(firstId + lines.length), raw));
    }
    return MarkdownLines._(
      lines,
      _detectIndentUnit(lines),
      firstId + lines.length,
    );
  }

  /// Parses [text] as a new version of this document, e.g. after it
  /// changed elsewhere. The unchanged lines at its start and end keep their
  /// ids, so a UI can keep its place there; all other lines get ids this
  /// document never used, so a UI cannot mistake a new line for an old one.
  MarkdownLines reparse(String text) {
    final raws = text.split('\n');
    var head = 0;
    while (head < raws.length &&
        head < lines.length &&
        raws[head] == lines[head].raw) {
      head++;
    }
    var tail = 0;
    while (tail < raws.length - head &&
        tail < lines.length - head &&
        raws[raws.length - 1 - tail] == lines[lines.length - 1 - tail].raw) {
      tail++;
    }
    var nextId = _nextId;
    final parsed = [
      ...lines.take(head),
      for (final raw in raws.sublist(head, raws.length - tail))
        MarkdownLine.parse(LineId(nextId++), raw),
      ...lines.skip(lines.length - tail),
    ];
    return MarkdownLines._(parsed, _detectIndentUnit(parsed), nextId);
  }

  /// All lines, in file order.
  final List<MarkdownLine> lines;

  /// One indent level as written in this file: two spaces unless the
  /// file already uses another indent.
  final String _indentUnit;

  final int _nextId;

  /// The kind of each line, by its place, e.g. inside a code block.
  late final List<LineKind> kinds = lineKinds([
    for (final line in lines) line.raw,
  ]);

  late final _indexById = {
    for (final (index, line) in lines.indexed) line.id: index,
  };

  /// Whether the document has checkbox items.
  bool get hasCheckboxes =>
      lines.indexed.any((entry) => _isItem(entry.$1) && entry.$2.isCheckbox);

  /// Whether [line] is a list item here: one by its syntax, outside code
  /// blocks and tables.
  bool isItem(MarkdownLine line) => _isItem(_indexOf(line.id));

  bool _isItem(int index) =>
      lines[index].isListItem && kinds[index] == LineKind.plain;

  bool _isChecked(int index) => _isItem(index) && lines[index].isChecked;

  String get text => lines.map((line) => line.raw).join('\n');

  /// Ids of checked items and of every line below them (their subitems),
  /// which a UI shows as done together.
  Set<LineId> get doneIds {
    final ids = <LineId>{};
    for (var i = 0; i < lines.length; i++) {
      if (!_isChecked(i)) continue;
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

  MarkdownLines toggle(LineId id) => _replaceLine(id, (line) => line.toggled());

  /// Toggles the checkbox [id] and, at the left margin, moves it with its
  /// subitems within its own list: once checked, below the list's last
  /// item; once unchecked, below its last open item at the margin, or
  /// above its first item if none is open. Open items are every item but
  /// checked checkboxes. A list ends at a line at the margin that is
  /// neither an item nor blank, e.g. a heading. A subitem
  /// toggles in place, under its item. Then every other checked item at
  /// the margin moves below too (see [sortChecked]), e.g. ones another
  /// editor left among the open items. Lines other than items stay in
  /// place, and an item with only such lines between it and its place
  /// does not move.
  MarkdownLines toggleAndSort(LineId id) => toggle(id).sortToggled(id);

  /// Moves the item [id], just toggled, as [toggleAndSort] does.
  MarkdownLines sortToggled(LineId id) => _sorted(id).sortChecked();

  /// Moves every checked item at the left margin, with its subitems, below
  /// the last item of its list, keeping their order; as [toggleAndSort]
  /// does for one.
  MarkdownLines sortChecked() => [
    for (final (index, line) in lines.indexed)
      if (_isChecked(index) && line.indent.isEmpty) line.id,
  ].fold(this, (list, id) => list._sorted(id));

  /// The item [id] moved to where [toggleAndSort] puts it.
  MarkdownLines _sorted(LineId id) {
    final index = _indexOf(id);
    if (lines[index].indent.isNotEmpty) return this;
    final target = _sortTarget(index);
    if (target == null) return this;
    final end = _blockEnd(index);
    final between = target < index
        ? lines.sublist(target, index)
        : lines.sublist(end, max(end, target));
    if (!between.any((line) => line.isListItem)) return this;
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
        if ((i < index || i >= end) && _isItem(i) && lines[i].indent.isEmpty) i,
    ];
    if (others.isEmpty) return null;
    if (_isChecked(index)) return _blockEnd(others.last);
    final open = others.where((i) => !_isChecked(i));
    return open.isEmpty ? others.first : _blockEnd(open.last);
  }

  /// The lists: runs of lines from an item to the last item or indented
  /// line before a line at the margin that is neither an item nor blank,
  /// e.g. a heading. Blank lines inside a run belong to it.
  List<List<MarkdownLine>> get lists {
    final runs = <List<MarkdownLine>>[];
    var i = 0;
    while (i < lines.length) {
      if (!_isItem(i)) {
        i++;
        continue;
      }
      var (_, end) = _listAround(i);
      while (lines[end - 1].raw.trim().isEmpty) {
        end--;
      }
      runs.add(lines.sublist(i, end));
      i = end;
    }
    return runs;
  }

  /// The list the line at [index] is in: from its first line to past its
  /// last, up to the lines at the margin that are neither items nor blank.
  (int, int) _listAround(int index) {
    var first = index;
    while (first > 0 && !_endsList(first - 1)) {
      first--;
    }
    var last = index + 1;
    while (last < lines.length && !_endsList(last)) {
      last++;
    }
    return (first, last);
  }

  bool _endsList(int index) =>
      !_isItem(index) &&
      lines[index].indent.isEmpty &&
      lines[index].raw.trim().isNotEmpty;

  /// Adds an empty item of [kind] next to the item [anchor]: just before
  /// it, at its level, so the items below never become its subitems; else
  /// at the left margin after it and its subitems, or for a subitem after
  /// the item at the margin it is under, so it never takes subitems of
  /// another. It takes the anchor's bullet style. Returns the new
  /// document and the new line's id.
  (MarkdownLines, LineId) addItem(
    ListKind kind, {
    required LineId anchor,
    required bool before,
  }) {
    final id = LineId(_nextId);
    if (before) {
      final index = _indexOf(anchor);
      return _insert(index, lines[index].newSibling(id, '', kind: kind));
    }
    final top = _marginItemOf(_indexOf(anchor));
    final sibling = lines[top].newSibling(id, '', kind: kind).withIndent('');
    return _insert(_blockEnd(top), sibling);
  }

  /// Line [id] as it shows [block] now: unchanged if it shows it already;
  /// else only its own line changes, keeping its prefix style (bullet,
  /// box, indent characters) where it can.
  MarkdownLines withBlock(LineId id, Block block) =>
      _replaceLine(id, (line) => _lineFor(line, block));

  MarkdownLine _lineFor(MarkdownLine line, Block block) => switch (block) {
    TextBlock(:final text) =>
      line.raw == text
          ? line
          : MarkdownLine.parse(line.id, MarkdownLine.oneLine(text)),
    ItemBlock() when !line.isListItem => _newItem(line.id, block, style: null),
    ItemBlock() => _item(line, block),
  };

  MarkdownLine _item(MarkdownLine line, ItemBlock block) {
    var item = switch (line) {
      _ when line.listKind != block.kind => line.withKind(
        block.kind,
        block.text,
      ),
      _ when line.text != block.text => line.withText(block.text),
      _ => line,
    };
    if (block.kind == ListKind.checkbox && item.isChecked != block.checked) {
      item = item.toggled();
    }
    if (depthOf(item) != block.depth) {
      item = item.withIndent(_indentUnit * block.depth);
    }
    return item;
  }

  /// A new item showing [block], with the bullet style of the item [style]
  /// if any.
  MarkdownLine _newItem(LineId id, ItemBlock block, {MarkdownLine? style}) {
    final unchecked = style == null
        ? MarkdownLine.newItem(id, block.kind, block.text)
        : style.newSibling(id, block.text, kind: block.kind);
    final item = unchecked.withIndent(_indentUnit * block.depth);
    return block.kind == ListKind.checkbox && block.checked
        ? item.toggled()
        : item;
  }

  /// Adds lines for [blocks], in order, right after the line [after] and
  /// its subitems up to [shownBelow], the line an editor shows right below
  /// [after], if any: subitems shown elsewhere (in a "Done" section) or
  /// not at all stay with [after]. At the top if [after] is `null`. New
  /// items take the bullet style of the item above them. Returns the new
  /// document and the new lines' ids.
  (MarkdownLines, List<LineId>) insertBlocks(
    List<Block> blocks, {
    required LineId? after,
    required LineId? shownBelow,
  }) {
    var at = 0;
    if (after != null) {
      final anchor = _indexOf(after);
      final width = _width(lines[anchor].indent);
      at = anchor + 1;
      while (at < lines.length &&
          lines[at].id != shownBelow &&
          lines[at].raw.trim().isNotEmpty &&
          _width(lines[at].indent) > width) {
        at++;
      }
    }
    final itemAbove = [
      for (var i = 0; i < at; i++)
        if (_isItem(i)) lines[i],
    ].lastOrNull;
    var nextId = _nextId;
    final added = [
      for (final block in blocks)
        switch (block) {
          TextBlock(:final text) => MarkdownLine.parse(
            LineId(nextId++),
            MarkdownLine.oneLine(text),
          ),
          ItemBlock() => _newItem(LineId(nextId++), block, style: itemAbove),
        },
    ];
    return (
      MarkdownLines._([...lines]..insertAll(at, added), _indentUnit, nextId),
      [for (final line in added) line.id],
    );
  }

  /// Removes only the line of [id]; lines below it (its subitems) stay
  /// where they are, as deleting an empty line in a text editor.
  MarkdownLines removeLine(LineId id) {
    return _with([...lines]..removeAt(_indexOf(id)));
  }

  /// Removes the item [id] with its subitems.
  MarkdownLines remove(LineId id) {
    final index = _indexOf(id);
    return _with([...lines]..removeRange(index, _blockEnd(index)));
  }

  /// Moves the item [id] with its subitems to just before the line
  /// [beforeId], or to the end if [beforeId] is `null`. Levels are kept.
  MarkdownLines move(LineId id, {required LineId? beforeId}) {
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

  /// Moves the item [id] with its subitems next to the line [target]:
  /// [below] it and its subitems, else just above it, as dropping it
  /// there. Levels are kept.
  MarkdownLines moveNextTo(
    LineId id, {
    required LineId target,
    required bool below,
  }) {
    if (!below) return move(id, beforeId: target);
    final end = _blockEnd(_indexOf(target));
    return move(id, beforeId: end < lines.length ? lines[end].id : null);
  }

  /// Moves the item [id] with its subitems one level right, under the
  /// line shown above it. Lines in [hidden] (e.g. done items a UI shows
  /// elsewhere) and empty lines are not shown; hidden lines in between
  /// move below the item, so it lands under the line the user saw.
  ///
  /// Does nothing if the line shown above is not an item, or if the item
  /// is already one level deeper than it.
  MarkdownLines indent(LineId id, {Set<LineId> hidden = const {}}) {
    final index = _indexOf(id);
    final above = _shownAbove(index, hidden);
    if (above == null || !_isItem(above)) return this;
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
  MarkdownLines outdent(LineId id) {
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
  int? _shownAbove(int index, Set<LineId> hidden) {
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
      if (!_isItem(i)) break;
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
            ? lines[i].withIndent(change(lines[i].indent))
            : lines[i],
    ]);
  }

  (MarkdownLines, LineId) _insert(int index, MarkdownLine line) => (
    MarkdownLines._([...lines]..insert(index, line), _indentUnit, _nextId + 1),
    line.id,
  );

  MarkdownLines _replaceLine(LineId id, MarkdownLine Function(MarkdownLine) f) {
    final index = _indexOf(id);
    return _with([...lines]..[index] = f(lines[index]));
  }

  MarkdownLines _with(List<MarkdownLine> lines) =>
      MarkdownLines._(lines, _indentUnit, _nextId);

  int _indexOf(LineId id) =>
      _indexById[id] ?? (throw ArgumentError.value(id, 'id', 'no such line'));

  static String _detectIndentUnit(List<MarkdownLine> lines) {
    String? unit;
    for (final line in lines) {
      if (!line.isListItem || line.indent.isEmpty) continue;
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
