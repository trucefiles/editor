import 'dart:math';

import 'block.dart';
import 'line_id.dart';
import 'markdown_line.dart';
import 'outline.dart';
import 'syntax/block_syntax.dart';
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

  /// The structure of the lines, read once.
  late final outline = Outline(lines, kinds, indentWidth(_indentUnit));

  late final _indexById = {
    for (final (index, line) in lines.indexed) line.id: index,
  };

  /// The line [id]; `null` if there is none.
  MarkdownLine? lineOf(LineId id) => switch (_indexById[id]) {
    final index? => lines[index],
    null => null,
  };

  /// The kind of [line] by its place here.
  LineKind kindOf(MarkdownLine line) => kinds[_indexOf(line.id)];

  /// Whether [line] shows in a quote: it has the quote's `>` marks, or it
  /// continues the paragraph of a quote above it without them, which
  /// Markdown keeps in the quote.
  bool isQuote(MarkdownLine line) => outline.isQuote(_indexOf(line.id));

  /// Whether the document has checkbox items.
  bool get hasCheckboxes =>
      lines.indexed.any((entry) => _isItem(entry.$1) && entry.$2.isCheckbox);

  /// Whether [line] is a list item here: one by its syntax, outside code
  /// blocks and tables.
  bool isItem(MarkdownLine line) => _isItem(_indexOf(line.id));

  bool _isItem(int index) => outline.isItem(index);

  bool _isChecked(int index) => _isItem(index) && lines[index].isChecked;

  String get text => lines.map((line) => line.raw).join('\n');

  /// Ids of checked items and of every line below them (their subitems),
  /// which a UI shows as done together.
  Set<LineId> get doneIds => {
    for (final (index, _) in lines.indexed)
      if (_isChecked(index)) ..._idsIn(outline.subtree(index)),
  };

  /// The number the numbered item [line] shows: as in Markdown, a run of
  /// numbered items at one level counts on from its first item's number,
  /// whatever the others say. `null` for any other line.
  int? numberOf(MarkdownLine line) => outline.numberAt(_indexOf(line.id));

  /// Nesting level of [line]: 0 at the left margin.
  int depthOf(MarkdownLine line) => outline.depthAt(_indexOf(line.id));

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
    final end = _subtreeEnd(index);
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
    final end = _subtreeEnd(index);
    final (start: first, end: last) = outline.regionOf(index);
    final others = [
      for (var i = first; i < last; i++)
        if ((i < index || i >= end) && _isItem(i) && lines[i].indent.isEmpty) i,
    ];
    if (others.isEmpty) return null;
    if (_isChecked(index)) return _subtreeEnd(others.last);
    final open = others.where((i) => !_isChecked(i));
    return open.isEmpty ? others.first : _subtreeEnd(open.last);
  }

  /// The lists: runs of lines from an item to the last item or indented
  /// line before a line at the margin that is neither an item nor blank,
  /// e.g. a heading. Blank lines inside a run belong to it.
  List<List<MarkdownLine>> get lists => [
    for (final span in outline.lists) _linesIn(span),
  ];

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
    final top = outline.marginItemOf(_indexOf(anchor));
    final sibling = lines[top].newSibling(id, '', kind: kind).withIndent('');
    return _insert(_subtreeEnd(top), sibling);
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
    final at = after == null ? 0 : _endBefore(_indexOf(after), shownBelow);
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
    final (:start, :end) = outline.subtree(_indexOf(id));
    return _with([...lines]..removeRange(start, end));
  }

  /// Moves the item [id] with its subitems to just before the line
  /// [beforeId], or to the end if [beforeId] is `null`. Levels are kept.
  MarkdownLines move(LineId id, {required LineId? beforeId}) {
    final (:start, :end) = outline.subtree(_indexOf(id));
    final block = lines.sublist(start, end);
    if (block.any((line) => line.id == beforeId)) return this;
    final rest = [...lines]..removeRange(start, end);
    final trailingEmpty = rest.length > 1 && rest.last.raw.isEmpty;
    final target = beforeId == null
        ? (trailingEmpty ? rest.length - 1 : rest.length)
        : rest.indexWhere((line) => line.id == beforeId);
    return _with(rest..insertAll(target, block));
  }

  /// Moves the item [id] with its subitems next to the line [target], as
  /// dropping it there: just above it, else [below] it. Below an item with
  /// subitems, it goes right under the item, before them.
  ///
  /// It takes the level of the spot it lands on: the target's, or below
  /// an item with subitems, theirs; so it never becomes the parent of the
  /// items below it. Its subitems keep their levels under it.
  MarkdownLines moveNextTo(
    LineId id, {
    required LineId target,
    required bool below,
  }) {
    final (:start, :end) = outline.subtree(_indexOf(id));
    final block = lines.sublist(start, end);
    if (block.any((line) => line.id == target)) return this;
    final rest = [...lines]..removeRange(start, end);
    final spot = _spotNextTo(
      rest,
      rest.indexWhere((l) => l.id == target),
      below,
    );
    // Below an item with subitems, the spot is theirs; as the user sees
    // them, also when the item is its own first subitem.
    final at = _indexOf(target);
    final indent =
        (below && at + 1 < _subtreeEnd(at) && _isItem(at + 1)
                ? lines[at + 1]
                : lines[at])
            .indent;
    final own = block.first.indent;
    // Lines of the block are deeper than the item; one indented with
    // other characters (a tab under spaces) stays one level deeper.
    String moved(String lineIndent) =>
        indent +
        (lineIndent.startsWith(own)
            ? lineIndent.substring(own.length)
            : _indentUnit);
    return _with(
      rest..insertAll(spot, [
        for (final line in block) line.withIndent(moved(line.indent)),
      ]),
    );
  }

  /// Where in [rest] an item dropped on the line at [target] goes: before
  /// it, or [below] it: before its first subitem, else after its block,
  /// before a final line break.
  int _spotNextTo(List<MarkdownLine> rest, int target, bool below) {
    if (!below) return target;
    final within = _with(rest);
    final end = within._subtreeEnd(target);
    if (target + 1 < end && within._isItem(target + 1)) return target + 1;
    final finalBreak =
        end == rest.length && rest.length > 1 && rest.last.raw.isEmpty;
    return finalBreak ? end - 1 : end;
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
    final aboveEnd = _subtreeEnd(above);
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
  int? _shownAbove(int index, Set<LineId> hidden) => [
    for (var i = 0; i < index; i++)
      if (lines[i].raw.trim().isNotEmpty && !hidden.contains(lines[i].id)) i,
  ].lastOrNull;

  /// Index just past the subtree of the line at [index].
  int _subtreeEnd(int index) => outline.subtree(index).end;

  /// Where lines go right after the line at [index] and the lines under
  /// it, stopping before [stop] if it is among them.
  int _endBefore(int index, LineId? stop) {
    final (start: _, :end) = outline.subtree(index);
    for (var i = index + 1; i < end; i++) {
      if (lines[i].id == stop) return i;
    }
    return end;
  }

  List<MarkdownLine> _linesIn(LineSpan span) =>
      lines.sublist(span.start, span.end);

  Iterable<LineId> _idsIn(LineSpan span) =>
      _linesIn(span).map((line) => line.id);

  MarkdownLines _reindentBlock(int index, String Function(String) change) {
    final (:start, :end) = outline.subtree(index);
    return _with([
      for (final (i, line) in lines.indexed)
        i >= start && i < end ? line.withIndent(change(line.indent)) : line,
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
      if (unit == null || indentWidth(line.indent) < indentWidth(unit)) {
        unit = line.indent;
      }
    }
    return unit ?? '  ';
  }
}
