import 'dart:math';

import 'package:collection/collection.dart';

import 'block.dart';
import 'line_id.dart';
import 'markdown_line.dart';
import 'outline.dart';
import 'syntax/block_syntax.dart';
import 'syntax/line_kinds.dart';

/// A place in a line: an offset in the line as in the file.
typedef LineCaret = ({LineId line, int offset});

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
  factory MarkdownLines.parse(String text) {
    final lines = _parseLines(text.split('\n'), firstId: 0);
    return MarkdownLines._(lines, _detectIndentUnit(lines), lines.length);
  }

  /// Parses [text] as a new version of this document, e.g. after it
  /// changed elsewhere. The unchanged lines at its start and end keep their
  /// ids, so a UI can keep its place there; all other lines get ids this
  /// document never used, so a UI cannot mistake a new line for an old one.
  MarkdownLines reparse(String text) {
    final raws = text.split('\n');
    final olds = [for (final line in lines) line.raw];
    final head = _sameAtStart(raws, olds);
    final tail = _sameAtStart(
      raws.skip(head).toList().reversed,
      olds.skip(head).toList().reversed,
    );
    final changed = _parseLines(
      raws.sublist(head, raws.length - tail),
      firstId: _nextId,
    );
    final parsed = [
      ...lines.take(head),
      ...changed,
      ...lines.skip(lines.length - tail),
    ];
    return MarkdownLines._(
      parsed,
      _detectIndentUnit(parsed),
      _nextId + changed.length,
    );
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
  late final Outline outline = Outline(lines, kinds);

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

  /// Where the text of [line] starts after its list marker; 0 for a line
  /// that is no item here.
  int textStartOf(MarkdownLine line) =>
      isItem(line) ? line.raw.length - line.text.length : 0;

  /// [caret], an offset in its line here, at the same place in the text
  /// after its list marker in [after], which may change the marker; `null`
  /// if [after] has no such line.
  LineCaret? caretIn(MarkdownLines after, LineCaret caret) {
    final (before, now) = (lineOf(caret.line), after.lineOf(caret.line));
    if (before == null || now == null) return null;
    final inText = caret.offset - textStartOf(before);
    return (line: now.id, offset: after.textStartOf(now) + max(0, inText));
  }

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

  /// Nesting level of [line]: the number of items it is under; 0 at the
  /// left margin.
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
      if (_isChecked(index) && outline.depthAt(index) == 0) line.id,
  ].fold(this, (list, id) => list._sorted(id));

  /// The item [id] moved to where [toggleAndSort] puts it.
  MarkdownLines _sorted(LineId id) {
    final index = _indexOf(id);
    if (!_isItem(index) || outline.depthAt(index) != 0) return this;
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
    final others = [...outline.listOf(index)]..remove(index);
    if (others.isEmpty) return null;
    if (_isChecked(index)) return _subtreeEnd(others.last);
    final open = others.where((i) => !_isChecked(i));
    return open.isEmpty ? others.first : _subtreeEnd(open.last);
  }

  /// The lists at the left margin: runs of items there, each with the
  /// lines under it; blank lines between them belong to the list. A line
  /// at the margin that is no item, e.g. a heading, ends a list.
  List<List<MarkdownLine>> get lists => [
    for (final span in outline.lists) _linesIn(span),
  ];

  /// Adds an empty item of [kind] next to the item [anchor]: just before
  /// it, at its level, so the items below never become its subitems; else
  /// at the left margin after it and its subitems, or for a subitem after
  /// the item at the margin it is under, so it never takes subitems of
  /// another. It takes the anchor's bullet style. [anchor] must be an
  /// item. Returns the new document and the new line's id.
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
    ItemBlock() when !line.isListItem => _newItem(
      line.id,
      block,
      at: _indexOf(line.id),
      style: null,
    ),
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
    final place = outline.placeAt(_indexOf(line.id), block.depth, _indentUnit);
    if (depthOf(line) != place.depth) item = item.withIndent(place.indent);
    return item;
  }

  /// A new item [id] showing [block] at index [at], placed there as
  /// [Outline.placeAt] says, with the bullet style of the item [style] if
  /// any.
  MarkdownLine _newItem(
    LineId id,
    ItemBlock block, {
    required int at,
    required MarkdownLine? style,
  }) {
    final unchecked = style == null
        ? MarkdownLine.newItem(id, block.kind, block.text)
        : style.newSibling(id, block.text, kind: block.kind);
    final place = outline.placeAt(at, block.depth, _indentUnit);
    final item = unchecked.withIndent(place.indent);
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
    return blocks.indexed.fold((this, const <LineId>[]), (done, entry) {
      final (document, ids) = done;
      final (offset, block) = entry;
      final (next, id) = document._insertBlock(at + offset, block);
      return (next, [...ids, id]);
    });
  }

  /// Adds a line for [block] at index [at].
  (MarkdownLines, LineId) _insertBlock(int at, Block block) {
    final id = LineId(_nextId);
    return _insert(at, switch (block) {
      TextBlock(:final text) => MarkdownLine.parse(
        id,
        MarkdownLine.oneLine(text),
      ),
      ItemBlock() => _newItem(
        id,
        block,
        at: at,
        style: lines.take(at).where(isItem).lastOrNull,
      ),
    });
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
  MarkdownLines move(LineId id, {required LineId? beforeId}) => _moveSubtree(
    _indexOf(id),
    spot: (rest, moved) => beforeId == null
        ? _endOf(rest)
        : _indexWithout(moved, _indexOf(beforeId)),
  );

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
    final at = _indexOf(target);
    return _moveSubtree(
      _indexOf(id),
      spot: (rest, moved) => switch (_indexWithout(moved, at)) {
        final index? => _spotNextTo(rest, index, below),
        null => null,
      },
      indent: _indentNextTo(at, below),
    );
  }

  /// The indent of the spot next to the line at [index]: its own, or
  /// [below] an item with subitems, theirs; as the user sees them, also
  /// when the item is its own first subitem.
  String _indentNextTo(int index, bool below) =>
      (below && index + 1 < _subtreeEnd(index) && _isItem(index + 1)
              ? lines[index + 1]
              : lines[index])
          .indent;

  /// Where in [rest] an item dropped on the line at [target] goes: before
  /// it, or [below] it: before its first subitem, else after its block,
  /// before a final line break.
  int _spotNextTo(List<MarkdownLine> rest, int target, bool below) {
    if (!below) return target;
    final within = _with(rest);
    final end = within._subtreeEnd(target);
    if (target + 1 < end && within._isItem(target + 1)) return target + 1;
    return end == rest.length ? _endOf(rest) : end;
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
    // Right after the lines under the item above, unless among them.
    final spot = min(_subtreeEnd(above), index);
    return _moveSubtree(
      index,
      spot: (_, _) => spot,
      indent: '${lines[index].indent}$_indentUnit',
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
    return _moveSubtree(
      index,
      spot: (_, _) => index,
      indent: indent.substring(0, indent.length - cut),
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
    if (index == 0) return null;
    final above = lines.lastIndexWhere(
      (line) => line.raw.trim().isNotEmpty && !hidden.contains(line.id),
      index - 1,
    );
    return above < 0 ? null : above;
  }

  /// Index just past the subtree of the line at [index].
  int _subtreeEnd(int index) => outline.subtree(index).end;

  /// Where lines go right after the line at [index] and the lines under
  /// it, stopping before [stop] if it is among them.
  int _endBefore(int index, LineId? stop) {
    final (start: _, :end) = outline.subtree(index);
    final under = _linesIn((start: index + 1, end: end));
    final stopAt = under.indexWhere((line) => line.id == stop);
    return stopAt < 0 ? end : index + 1 + stopAt;
  }

  List<MarkdownLine> _linesIn(LineSpan span) =>
      lines.sublist(span.start, span.end);

  Iterable<LineId> _idsIn(LineSpan span) =>
      _linesIn(span).map((line) => line.id);

  /// Takes the item at [index] with its subitems out and puts them back
  /// where [spot] says: it gets the remaining lines and the span taken,
  /// and returns the index in them, or `null` to leave the document as it
  /// is. With [indent], the item gets it and the lines under it follow
  /// (see [_under]).
  MarkdownLines _moveSubtree(
    int index, {
    required int? Function(List<MarkdownLine> rest, LineSpan moved) spot,
    String? indent,
  }) {
    final span = outline.subtree(index);
    final rest = [...lines]..removeRange(span.start, span.end);
    final at = spot(rest, span);
    if (at == null) return this;
    final [item, ...under] = _linesIn(span);
    return _with(
      rest..insertAll(at, [
        if (indent == null) ...[
          item,
          ...under,
        ] else ...[
          item.withIndent(indent),
          for (final line in under) _under(line, from: item.indent, to: indent),
        ],
      ]),
    );
  }

  /// [line], under an item, once the item's indent changes [from] one [to]
  /// another. A blank line needs no indent and stays as it is. A line no
  /// deeper than the item (text that continues it without indent) lands
  /// one level under it, so it stays the item's wherever it goes. Any
  /// other keeps its indent relative to the item: as written, else
  /// (indented with other characters, e.g. a tab under spaces) as wide, in
  /// spaces.
  MarkdownLine _under(
    MarkdownLine line, {
    required String from,
    required String to,
  }) {
    if (line.raw.trim().isEmpty) return line;
    final deeper = indentWidth(line.indent) - indentWidth(from);
    return line.withIndent(switch (line.indent) {
      _ when deeper <= 0 => '$to$_indentUnit',
      final indent when indent.startsWith(from) =>
        '$to${indent.substring(from.length)}',
      _ => '$to${' ' * deeper}',
    });
  }

  /// The index the line at [index] has once the lines of [span] are taken
  /// out; `null` if it is among them.
  static int? _indexWithout(LineSpan span, int index) => index < span.start
      ? index
      : (index >= span.end ? index - (span.end - span.start) : null);

  /// The end of [lines], before a final line break (an empty last line).
  static int _endOf(List<MarkdownLine> lines) =>
      lines.length > 1 && lines.last.raw.isEmpty
      ? lines.length - 1
      : lines.length;

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

  /// The least indent of the indented items in [lines]; two spaces if
  /// none is.
  static String _detectIndentUnit(List<MarkdownLine> lines) =>
      minBy([
        for (final line in lines)
          if (line.isListItem && line.indent.isNotEmpty) line.indent,
      ], indentWidth) ??
      '  ';

  /// Lines parsed from [raws], with ids counting up from [firstId].
  static List<MarkdownLine> _parseLines(
    List<String> raws, {
    required int firstId,
  }) => [
    for (final (offset, raw) in raws.indexed)
      MarkdownLine.parse(LineId(firstId + offset), raw),
  ];
}

/// How many items [a] and [b] have equal at their start.
int _sameAtStart(Iterable<String> a, Iterable<String> b) =>
    IterableZip([a, b]).takeWhile((pair) => pair[0] == pair[1]).length;
