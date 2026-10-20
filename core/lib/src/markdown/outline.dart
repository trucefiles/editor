import 'markdown_line.dart';
import 'syntax/block_syntax.dart';
import 'syntax/line_kinds.dart';

/// The lines from [start] to [end] (exclusive) of a document, by index.
typedef LineSpan = ({int start, int end});

/// One part of a document at its top level, in file order.
sealed class OutlineBlock {
  const OutlineBlock(this.span);

  final LineSpan span;
}

/// A list: from its first item to its last line that is not blank.
final class ListBlock extends OutlineBlock {
  const ListBlock(super.span);
}

/// A table: its header, delimiter row and rows.
final class TableBlock extends OutlineBlock {
  const TableBlock(super.span);
}

/// Any other line.
final class LineBlock extends OutlineBlock {
  const LineBlock(super.span);
}

/// The structure of a document's lines, read once from them: the tree of
/// lines under lines (an item's subitems and text, up to an empty line),
/// the lists, and what each line shows by its place (number, quote).
/// Immutable; every question is a lookup. A changed document gets a new
/// outline.
final class Outline {
  /// The outline of [_lines] of [_kinds], one indent level being
  /// [_unitWidth] wide.
  Outline(this._lines, this._kinds, this._unitWidth)
    : _items = [
        for (final (index, line) in _lines.indexed)
          line.isListItem && _kinds[index] == LineKind.plain,
      ];

  final List<MarkdownLine> _lines;
  final List<LineKind> _kinds;
  final List<bool> _items;

  /// The width of one indent level.
  final int _unitWidth;

  late final List<int> _subtreeEnds = _readSubtreeEnds();
  late final List<int> _marginItems = _readMarginItems();
  late final List<LineSpan> _regions = _readRegions();
  late final List<int?> _numbers = _readNumbers();
  late final List<bool> _quotes = _readQuotes();

  /// Whether the line at [index] is a list item: one by its syntax,
  /// outside code blocks and tables.
  bool isItem(int index) => _items[index];

  /// Nesting level of the line at [index]: 0 at the left margin.
  int depthAt(int index) => indentWidth(_lines[index].indent) ~/ _unitWidth;

  /// The line at [index] with the lines under it: every following line
  /// indented deeper, up to an empty line.
  LineSpan subtree(int index) => (start: index, end: _subtreeEnds[index]);

  /// The index of the item at the left margin that the item at [index] is
  /// under: the nearest less indented item above, up to the margin, within
  /// its run of items; [index] itself at the margin.
  int marginItemOf(int index) => _marginItems[index];

  /// The list region the line at [index] is in: up to the lines around it
  /// at the margin that are neither items nor blank.
  LineSpan regionOf(int index) => _regions[index];

  /// The number the numbered item at [index] shows: as in Markdown, a run
  /// of numbered items at one level counts on from its first item's
  /// number, whatever the others say. `null` for any other line.
  int? numberAt(int index) => _numbers[index];

  /// Whether the line at [index] shows in a quote: it has the quote's `>`
  /// marks, or it continues the paragraph of a quote above it without
  /// them, which Markdown keeps in the quote.
  bool isQuote(int index) => _quotes[index];

  /// The document's top-level parts, in file order: lists, tables and
  /// the lines between them.
  late final List<OutlineBlock> blocks = _readBlocks();

  /// The lists, in file order.
  late final List<LineSpan> lists = [
    for (final block in blocks)
      if (block is ListBlock) block.span,
  ];

  bool _isBlank(int index) => _lines[index].raw.trim().isEmpty;

  int _widthAt(int index) => indentWidth(_lines[index].indent);

  /// A line ends the subtrees above it that are not less indented than
  /// it; an empty line ends all of them.
  List<int> _readSubtreeEnds() {
    final ends = List.filled(_lines.length, _lines.length);
    final open = <int>[];
    for (var index = 0; index < _lines.length; index++) {
      while (open.isNotEmpty &&
          (_isBlank(index) || _widthAt(open.last) >= _widthAt(index))) {
        ends[open.removeLast()] = index;
      }
      open.add(index);
    }
    return ends;
  }

  /// Along each run of items, the less indented items above each one, of
  /// which the first is its item at the margin.
  List<int> _readMarginItems() {
    final margins = List.generate(_lines.length, (index) => index);
    final above = <int>[];
    for (var index = 0; index < _lines.length; index++) {
      if (!_items[index]) {
        above.clear();
        continue;
      }
      while (above.isNotEmpty && _widthAt(above.last) >= _widthAt(index)) {
        above.removeLast();
      }
      if (above.isNotEmpty) margins[index] = above.first;
      above.add(index);
    }
    return margins;
  }

  bool _endsList(int index) =>
      !_items[index] && _lines[index].indent.isEmpty && !_isBlank(index);

  /// Runs of lines between the lines that end lists; a line that ends one
  /// is a region of its own.
  List<LineSpan> _readRegions() {
    final regions = List<LineSpan>.filled(_lines.length, (start: 0, end: 0));
    var start = 0;
    for (var index = 0; index <= _lines.length; index++) {
      if (index < _lines.length && !_endsList(index)) continue;
      for (var line = start; line < index; line++) {
        regions[line] = (start: start, end: index);
      }
      if (index < _lines.length) {
        regions[index] = (start: index, end: index + 1);
      }
      start = index + 1;
    }
    return regions;
  }

  /// Per region, the count at each level: an item ends the counts of the
  /// levels below it; one not numbered also ends its own.
  List<int?> _readNumbers() {
    final numbers = List<int?>.filled(_lines.length, null);
    var counts = <int, int>{};
    LineSpan? region;
    for (var index = 0; index < _lines.length; index++) {
      if (regionOf(index) != region) {
        region = regionOf(index);
        counts = {};
      }
      if (!_items[index]) continue;
      final depth = depthAt(index);
      counts.removeWhere((level, _) => level > depth);
      final line = _lines[index];
      if (line.listKind != ListKind.numbered) {
        counts.remove(depth);
        continue;
      }
      numbers[index] = counts[depth] = switch (counts[depth]) {
        final count? => count + 1,
        null => line.number!,
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

  /// Lists first, from their first item to their region's last line that
  /// is not blank; then tables among the other lines.
  List<OutlineBlock> _readBlocks() {
    final tables = {for (final (start, end) in tableRanges(_kinds)) start: end};
    final blocks = <OutlineBlock>[];
    var index = 0;
    while (index < _lines.length) {
      final block = _items[index]
          ? ListBlock((start: index, end: _listEnd(index)))
          : switch (tables[index]) {
              final end? => TableBlock((start: index, end: end)),
              null => LineBlock((start: index, end: index + 1)),
            };
      blocks.add(block);
      index = block.span.end;
    }
    return blocks;
  }

  int _listEnd(int index) {
    var end = regionOf(index).end;
    while (_isBlank(end - 1)) {
      end--;
    }
    return end;
  }
}

/// Visual width of leading whitespace; a tab counts as four spaces.
int indentWidth(String indent) =>
    indent.runes.fold(0, (sum, rune) => sum + (rune == 0x09 ? 4 : 1));
