import 'block_reader.dart';
import 'markdown_line.dart';
import 'syntax/block_syntax.dart';
import 'syntax/line_kinds.dart';

/// The lines from [start] to [end] (exclusive) of a document, by index.
typedef LineSpan = ({int start, int end});

/// Where a line put at a level lands, by the lines around it: [depth] is
/// the level it gets.
sealed class LinePlace {
  const LinePlace(this.depth);

  final int depth;
}

/// At the left margin, under no item.
final class AtMargin extends LinePlace {
  const AtMargin() : super(0);
}

/// Beside [item], at its level.
final class BesideItem extends LinePlace {
  const BesideItem(this.item, super.depth);

  final MarkdownLine item;
}

/// One level under [item].
final class UnderItem extends LinePlace {
  const UnderItem(this.item, super.depth);

  final MarkdownLine item;
}

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
/// reads it ([readLines]): a tree in which a list item holds the lines
/// in it, blank lines among them included, and every other line is a
/// leaf; runs of items at one level form lists. Immutable; every question
/// is a lookup. A changed document gets a new outline.
final class Outline {
  /// The outline of [_lines].
  Outline(this._lines) : _reads = readLines(_lines);

  final List<MarkdownLine> _lines;
  final List<LineRead> _reads;

  /// The node of each line; `null` for a blank line.
  late final List<_Node?> _nodes = _readTree();
  late final List<int?> _numbers = _readNumbers();

  /// The kind of each line, by its place, e.g. inside a code block.
  late final List<LineKind> kinds = [for (final read in _reads) read.kind];

  /// Whether the line at [index] is a list item: one by its syntax, where
  /// Markdown reads one (not in a code block, not continuing text).
  bool isItem(int index) => _reads[index].isItem;

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
    assert(isItem(index), 'only an item has a margin item');
    return _nodes[index]!.top.index;
  }

  /// The indices of the items of the list the item at [index] is in, at
  /// its level, in file order, [index] included. Only for items.
  List<int> listOf(int index) {
    assert(isItem(index), 'only an item is in a list');
    return [for (final item in _nodes[index]!.list!) item.index];
  }

  /// Where a line put at [index], between the lines before it and the
  /// line now there, lands at [depth], as deep as Markdown lets it there:
  /// beside the first line from [index] on that is not blank, if it is an
  /// item at that depth, so that item stays beside it; else beside the
  /// item at that depth that the nearest line above is in or is; else at
  /// the margin for the top level; else under the deepest item that line
  /// is in or is; else at the margin. The one owner of where a level puts
  /// a line.
  LinePlace placeAt(int index, int depth) {
    final below = _nodes.skip(index).nonNulls.firstOrNull;
    if (below != null && below.isItem && below.depth == depth) {
      return BesideItem(_lines[below.index], depth);
    }
    final above = _nodes.take(index).nonNulls.lastOrNull;
    final chain = [
      for (var node = above; node != null; node = node.parent)
        if (node.isItem) node,
    ];
    return switch ((
      chain.where((node) => node.depth == depth).firstOrNull,
      chain.firstOrNull,
    )) {
      (final sibling?, _) => BesideItem(_lines[sibling.index], depth),
      _ when depth == 0 => const AtMargin(),
      (null, final parent?) => UnderItem(
        _lines[parent.index],
        parent.depth + 1,
      ),
      _ => const AtMargin(),
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
  bool isQuote(int index) => _reads[index].inQuote;

  /// The line of a heading written as text over `===` or `---` that the
  /// line at [index] is; `null` for any other line.
  UnderlinedHeadingLine? underlinedHeadingAt(int index) =>
      _reads[index].heading;

  /// The document's top-level parts, in file order: lists, tables and
  /// the lines between them.
  late final List<OutlinePart> parts = _readParts();

  /// The lists at the top level, in file order.
  late final List<LineSpan> lists = [
    for (final part in parts)
      if (part is ListPart) part.span,
  ];

  /// Each line that is not blank goes under the item the reader put it
  /// in. An item joins the list of the item just before it at its level,
  /// if any.
  List<_Node?> _readTree() {
    final nodes = List<_Node?>.filled(_lines.length, null);
    final roots = <_Node>[];
    for (final (index, read) in _reads.indexed) {
      if (read.isBlank) continue;
      final parent = switch (read.parent) {
        final item? => nodes[item],
        null => null,
      };
      final siblings = parent?.children ?? roots;
      final node = _Node(
        index,
        parent,
        list: read.isItem ? (siblings.lastOrNull?.list ?? <_Node>[]) : null,
      );
      siblings.add(node);
      node.list?.add(node);
      nodes[index] = node;
    }
    return nodes;
  }

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

  /// Lists from their first item to the last line under their last item;
  /// tables; every other line on its own.
  List<OutlinePart> _readParts() {
    final parts = <OutlinePart>[];
    var index = 0;
    while (index < _lines.length) {
      final part = _partAt(index);
      parts.add(part);
      index = part.span.end;
    }
    return parts;
  }

  /// The part that starts at [index].
  OutlinePart _partAt(int index) => switch (_nodes[index]) {
    _Node(:final list?, parent: null) => ListPart((
      start: index,
      end: list.last.end,
    )),
    _ when kinds[index] == LineKind.table => TablePart((
      start: index,
      end: _endOfTable(index),
    )),
    _ => LinePart((start: index, end: index + 1)),
  };

  /// The index past the last line of the table the line at [index] is in.
  int _endOfTable(int index) =>
      switch (kinds.indexWhere((kind) => kind != LineKind.table, index)) {
        -1 => _lines.length,
        final end => end,
      };
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
