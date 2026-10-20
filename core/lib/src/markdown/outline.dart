import 'markdown_line.dart';
import 'syntax/block_syntax.dart';
import 'syntax/line_kinds.dart';

/// The lines from [start] to [end] (exclusive) of a document, by index.
typedef LineSpan = ({int start, int end});

/// Where a line lands: its [depth], and the [indent] that puts it there.
typedef LinePlace = ({int depth, String indent});

/// One part of a document at its top level, in file order.
sealed class OutlinePart {
  const OutlinePart(this.span);

  final LineSpan span;
}

/// A list: its items at the margin with the lines under them.
final class ListPart extends OutlinePart {
  const ListPart(super.span);
}

/// A table: its header, delimiter row and rows.
final class TablePart extends OutlinePart {
  const TablePart(super.span);
}

/// Any other line.
final class LinePart extends OutlinePart {
  const LinePart(super.span);
}

/// The structure of a document's lines, read once from them as Markdown
/// reads it: a tree in which a list item holds the lines indented under
/// it, blank lines among them included, and every other line is a leaf;
/// runs of items at one level form lists. Immutable; every question is a
/// lookup. A changed document gets a new outline.
final class Outline {
  /// The outline of [_lines] of [_kinds].
  Outline(this._lines, this._kinds)
    : _items = [
        for (final (index, line) in _lines.indexed)
          line.isListItem && _kinds[index] == LineKind.plain,
      ];

  final List<MarkdownLine> _lines;
  final List<LineKind> _kinds;
  final List<bool> _items;

  /// The node of each line; `null` for a blank line.
  late final List<_Node?> _nodes = _readTree();
  late final List<int?> _numbers = _readNumbers();
  late final List<bool> _quotes = _readQuotes();

  /// Whether the line at [index] is a list item: one by its syntax,
  /// outside code blocks and tables.
  bool isItem(int index) => _items[index];

  /// Nesting level of the line at [index]: the number of items it is
  /// under; 0 at the top level.
  int depthAt(int index) => _nodes[index]?.depth ?? 0;

  /// The line at [index] with the lines under it, if it is an item: up to
  /// its last line that is not blank.
  LineSpan subtree(int index) =>
      (start: index, end: _nodes[index]?.end ?? index + 1);

  /// The index of the item at the top level that the item at [index] is
  /// under; [index] itself at the top level. Only for items.
  int marginItemOf(int index) {
    assert(_items[index], 'only an item has a margin item');
    return _nodes[index]!.top.index;
  }

  /// The indices of the items of the list the item at [index] is in, at
  /// its level, in file order, [index] included. Only for items.
  List<int> listOf(int index) {
    assert(_items[index], 'only an item is in a list');
    return [for (final item in _nodes[index]!.list!) item.index];
  }

  /// Where an item put right after the lines before [index] lands at
  /// [depth], as deep as Markdown lets it there: beside the item at that
  /// depth that the nearest line above is in or is, else [unit] deeper
  /// than the deepest item that line is in or is; at the margin if none.
  LinePlace placeAt(int index, int depth, String unit) {
    if (depth == 0) return (depth: 0, indent: '');
    final above = _nodes.take(index).nonNulls.lastOrNull;
    final chain = [
      for (var node = above; node != null; node = node.parent)
        if (node.isItem) node,
    ];
    if (chain.where((node) => node.depth == depth).firstOrNull
        case final sibling?) {
      return (depth: depth, indent: _lines[sibling.index].indent);
    }
    return switch (chain.firstOrNull) {
      final parent? => (
        depth: parent.depth + 1,
        indent: '${_lines[parent.index].indent}$unit',
      ),
      null => (depth: 0, indent: ''),
    };
  }

  /// The number the numbered item at [index] shows: as in Markdown, a run
  /// of numbered items in one list, written with one delimiter, counts on
  /// from its first item's number, whatever the others say. `null` for
  /// any other line.
  int? numberAt(int index) => _numbers[index];

  /// Whether the line at [index] shows in a quote: it has the quote's `>`
  /// marks, or it continues the paragraph of a quote above it without
  /// them, which Markdown keeps in the quote.
  bool isQuote(int index) => _quotes[index];

  /// The document's top-level parts, in file order: lists, tables and
  /// the lines between them.
  late final List<OutlinePart> parts = _readParts();

  /// The lists at the top level, in file order.
  late final List<LineSpan> lists = [
    for (final part in parts)
      if (part is ListPart) part.span,
  ];

  bool _isBlank(int index) => _lines[index].raw.trim().isEmpty;

  int _widthAt(int index) => indentWidth(_lines[index].indent);

  /// Each line goes under the nearest item above it that is less
  /// indented; a line of a code block or table goes where the block's
  /// first line went. An item joins the list of the item just before it
  /// at its level, if any.
  List<_Node?> _readTree() {
    final nodes = List<_Node?>.filled(_lines.length, null);
    final roots = <_Node>[];
    final open = <_Node>[];
    for (var index = 0; index < _lines.length; index++) {
      if (_kinds[index] == LineKind.plain && _isBlank(index)) continue;
      final parent = _continuesBlock(index)
          ? nodes[index - 1]!.parent
          : _popToParent(open, index);
      final siblings = parent?.children ?? roots;
      final node = _Node(
        index,
        parent,
        list: _items[index] ? (siblings.lastOrNull?.list ?? <_Node>[]) : null,
      );
      siblings.add(node);
      node.list?.add(node);
      nodes[index] = node;
      if (node.isItem) open.add(node);
    }
    return nodes;
  }

  /// Closes the items of [open], innermost last, that the line at [index]
  /// is not indented under; the innermost one left is its parent.
  _Node? _popToParent(List<_Node> open, int index) {
    while (open.isNotEmpty && _widthAt(open.last.index) >= _widthAt(index)) {
      open.removeLast();
    }
    return open.lastOrNull;
  }

  /// Whether the line at [index] continues a block above it: a code
  /// block's lines and closing fence, a table's lines after the first.
  bool _continuesBlock(int index) =>
      index > 0 &&
      switch ((_kinds[index - 1], _kinds[index])) {
        (_, LineKind.code) => true,
        (LineKind.code, LineKind.fence) => true,
        (LineKind.fence, LineKind.fence) => !_continuesBlock(index - 1),
        (LineKind.table, LineKind.table) => true,
        _ => false,
      };

  /// In file order, each numbered item counts on from the item just
  /// before it in its list if it may (see [MarkdownLine.countsOnFrom]),
  /// else from its own number.
  List<int?> _readNumbers() {
    final numbers = List<int?>.filled(_lines.length, null);
    for (final node in _nodes.nonNulls) {
      final line = _lines[node.index];
      if (!node.isItem || line.listKind != ListKind.numbered) continue;
      numbers[node.index] = switch (node.previousItem) {
        final previous? when line.countsOnFrom(_lines[previous.index]) =>
          numbers[previous.index]! + 1,
        _ => line.number!,
      };
    }
    return numbers;
  }

  List<bool> _readQuotes() {
    final quotes = List.filled(_lines.length, false);
    // Whether the line above ends inside a quote's paragraph.
    var inParagraph = false;
    for (final (index, line) in _lines.indexed) {
      final raw = line.raw;
      final marked = quoteTextStart(raw);
      final text = marked == null ? raw : raw.substring(marked);
      quotes[index] =
          _kinds[index] == LineKind.plain &&
          (marked != null ||
              (inParagraph && raw.trim().isNotEmpty && !startsBlock(raw)));
      inParagraph =
          quotes[index] && text.trim().isNotEmpty && !startsBlock(text);
    }
    return quotes;
  }

  /// Lists from their first item to the last line under their last item;
  /// tables; every other line on its own.
  List<OutlinePart> _readParts() {
    final tables = {for (final (start, end) in tableRanges(_kinds)) start: end};
    final parts = <OutlinePart>[];
    var index = 0;
    while (index < _lines.length) {
      final part = switch (_nodes[index]) {
        _Node(:final list?, parent: null) => ListPart((
          start: index,
          end: list.last.end,
        )),
        _ => switch (tables[index]) {
          final end? => TablePart((start: index, end: end)),
          null => LinePart((start: index, end: index + 1)),
        },
      };
      parts.add(part);
      index = part.span.end;
    }
    return parts;
  }
}

/// A line that is not blank, in the tree of its document. Built once by
/// [Outline._readTree], which adds it to its lists.
final class _Node {
  _Node(this.index, this.parent, {required this.list})
    : _position = list?.length ?? 0;

  /// The line's index.
  final int index;

  /// The item the line is under, if any.
  final _Node? parent;

  /// The lines under it, in file order; only an item has any.
  final List<_Node> children = [];

  /// The items of its list, in file order, if it is an item; shared by
  /// them.
  final List<_Node>? list;

  final int _position;

  bool get isItem => list != null;

  /// The item before it in its list, if any.
  _Node? get previousItem => _position == 0 ? null : list![_position - 1];

  late final int depth = parent == null ? 0 : parent!.depth + 1;

  /// The index past its last line, with the lines under it.
  late final int end = children.isEmpty ? index + 1 : children.last.end;

  /// The item at the top level it is under; itself at the top level.
  late final _Node top = parent?.top ?? this;
}

/// Visual width of leading whitespace; a tab counts as four spaces.
int indentWidth(String indent) =>
    indent.runes.fold(0, (sum, rune) => sum + (rune == 0x09 ? 4 : 1));
