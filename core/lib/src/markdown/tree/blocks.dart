import '../lines/line_id.dart';
import '../lines/markdown_line.dart';

/// One block of a Markdown document as CommonMark and GitHub Flavored
/// Markdown read it: a container that holds blocks, or a leaf that holds
/// lines. Read once by `MarkdownTree.read`; immutable once read.
sealed class MarkdownBlock {
  MarkdownBlock();

  /// The container this block is in; `null` for the root.
  ContainerBlock? get parent => _parent;
  ContainerBlock? _parent;

  /// The containers this block is in, innermost first.
  Iterable<ContainerBlock> get ancestors sync* {
    for (var block = parent; block != null; block = block.parent) {
      yield block;
    }
  }

  /// The leaves in it, in file order: itself for a leaf.
  List<LeafBlock> get leaves;

  /// Its first and last line.
  MarkdownLine get firstLine => leaves.first.lines.first.line;
  MarkdownLine get lastLine => leaves.last.lines.last.line;
}

/// A block that holds other blocks, in file order.
sealed class ContainerBlock extends MarkdownBlock {
  ContainerBlock();

  List<MarkdownBlock> get children => _children;
  List<MarkdownBlock> _children = const [];

  @override
  late final List<LeafBlock> leaves = [
    for (final child in _children) ...child.leaves,
  ];

  /// Sets the [children], once, as the reader built them.
  void adopt(List<MarkdownBlock> children) {
    _children = List.unmodifiable(children);
    for (final child in children) {
      child._parent = this;
    }
  }
}

/// The whole document.
final class RootBlock extends ContainerBlock {
  RootBlock();
}

/// A block quote: lines marked with `>`, and lazy text continuing them.
final class QuoteBlock extends ContainerBlock {
  QuoteBlock();
}

/// The kinds of list items.
enum ListKind {
  /// `- [ ] text`, with a box to check.
  checkbox,

  /// `- text`.
  bullet,

  /// `1. text`.
  numbered,
}

/// How a list item's marker is written: a [bullet] character, or a
/// [number] with its [delimiter] (`.` or `)`).
final class ItemMarker {
  const ItemMarker.bullet(String this.bullet) : number = null, delimiter = null;

  const ItemMarker.numbered(int this.number, String this.delimiter)
    : bullet = null;

  final String? bullet;
  final int? number;
  final String? delimiter;

  bool get isNumbered => number != null;

  /// Whether an item with [other] continues the same list: as in
  /// Markdown, the same bullet character, or numbers with the same
  /// delimiter.
  bool sameListAs(ItemMarker other) => isNumbered
      ? other.isNumbered && other.delimiter == delimiter
      : other.bullet == bullet;
}

/// A list: a run of items with markers of one list (see
/// [ItemMarker.sameListAs]), and the blank lines between them.
final class ListBlock extends ContainerBlock {
  ListBlock({required this.tight});

  /// Whether no blank line separates its items or their blocks.
  final bool tight;

  late final List<ItemBlock> items = children.whereType<ItemBlock>().toList();
}

/// A list item: its marker line and the blocks in it.
final class ItemBlock extends ContainerBlock {
  ItemBlock({
    required this.markerLine,
    required this.marker,
    required this.checked,
    required this.markerColumn,
    required this.contentColumn,
  });

  /// The line its marker is on.
  final LineId markerLine;

  final ItemMarker marker;

  /// Whether its box is checked; `null` if it has no box.
  final bool? checked;

  /// The column its marker starts at, from where its container's content
  /// starts.
  final int markerColumn;

  /// The column its content starts at, from where its container's content
  /// starts: lines in it are indented at least this far.
  final int contentColumn;

  ListKind get kind => checked != null
      ? ListKind.checkbox
      : (marker.isNumbered ? ListKind.numbered : ListKind.bullet);

  bool get isChecked => checked ?? false;
}

/// The part of a line a container takes: its `>`, or an item's marker or
/// indent; from [start] to [end] in the line.
typedef PrefixSegment = ({ContainerBlock container, int start, int end});

/// One line of a leaf: what of it is the leaf's own, from [contentStart]
/// on, and what the containers took before it ([prefix]).
final class LeafLine {
  const LeafLine(
    this.line, {
    required this.contentStart,
    required this.prefix,
    this.virtualSpaces = 0,
  });

  final MarkdownLine line;

  /// Where the leaf's part of the line starts.
  final int contentStart;

  /// The containers' parts of the line, outermost first. A lazy line
  /// lacks the parts of containers it continues without their marks.
  final List<PrefixSegment> prefix;

  /// Columns of a tab before [contentStart] that a container took only in
  /// part: they show as spaces in a code block.
  final int virtualSpaces;

  LineId get id => line.id;

  /// Where the leaf's part of the line ends: before a carriage return
  /// that ends it.
  int get contentEnd =>
      line.raw.endsWith('\r') ? line.raw.length - 1 : line.raw.length;

  /// The leaf's part of the line.
  String get content => contentStart >= contentEnd
      ? ''
      : line.raw.substring(contentStart, contentEnd);
}

/// A block that holds lines and no blocks.
sealed class LeafBlock extends MarkdownBlock {
  LeafBlock(this.lines);

  /// Its lines, in file order; at least one.
  final List<LeafLine> lines;

  /// Its first line's id: stable while that line stays first.
  LineId get id => lines.first.id;

  @override
  List<LeafBlock> get leaves => [this];

  /// Its lines' contents, joined by line breaks.
  late final String text = lines.map((line) => line.content).join('\n');

  /// Where each line's content starts in [text].
  late final List<int> lineStarts = lines.take(lines.length - 1).fold([
    0,
  ], (starts, line) => [...starts, starts.last + line.content.length + 1]);

  /// Its line [id]. Only for one of its lines.
  LeafLine lineOf(LineId id) => lines.firstWhere((line) => line.id == id);

  /// The index of the line [offset] in [text] is on.
  int lineAt(int offset) => lineStarts
      .lastIndexWhere((start) => start <= offset)
      .clamp(0, lines.length - 1);
}

/// Lines of text.
final class ParagraphBlock extends LeafBlock {
  ParagraphBlock(super.lines);
}

/// A heading: `# Title` ([setext] false) or text over `===` or `---`.
final class HeadingBlock extends LeafBlock {
  HeadingBlock(
    super.lines, {
    required this.level,
    required this.setext,
    required this.textStart,
    required this.textEnd,
  });

  /// 1 to 6.
  final int level;
  final bool setext;

  /// Where its text starts and ends in [text], without its marks.
  final int textStart;
  final int textEnd;
}

/// A code block: fenced, with its fences as its first and (if closed)
/// last line, or indented.
final class CodeBlock extends LeafBlock {
  CodeBlock(
    super.lines, {
    required this.fenced,
    required this.closed,
    this.info = '',
  });

  final bool fenced;

  /// Whether a fenced block has its closing fence.
  final bool closed;

  /// The info string after the opening fence, unescaped.
  final String info;

  /// The lines of code, without fences.
  List<LeafLine> get codeLines => fenced
      ? lines.sublist(1, closed ? lines.length - 1 : lines.length)
      : lines;
}

/// A block of HTML, kept as written.
final class HtmlBlock extends LeafBlock {
  HtmlBlock(super.lines);
}

/// How a table column's cells line up.
enum CellAlignment { none, left, center, right }

/// One cell of a table row, from [start] to [end] in its line's
/// content, without the pipes and surrounding spaces.
typedef TableCell = ({int start, int end});

/// A table: its header row, delimiter row, and rows.
final class TableBlock extends LeafBlock {
  TableBlock(super.lines, {required this.alignments, required this.cells});

  final List<CellAlignment> alignments;

  /// The cells of each line but the delimiter row (header first), as
  /// many as [alignments]; a missing cell is `null`.
  final List<List<TableCell?>> cells;
}

/// A thematic break: `---`, `***` or `___`.
final class RuleBlock extends LeafBlock {
  RuleBlock(super.lines);
}

/// A link reference definition: `[label]: destination "title"`.
typedef LinkDefinition = ({String label, String destination, String? title});

/// Lines of link reference definitions.
final class DefinitionsBlock extends LeafBlock {
  DefinitionsBlock(super.lines, this.definitions);

  final List<LinkDefinition> definitions;
}

/// Front matter: YAML between `---` lines at the very top of a document.
/// Not CommonMark, but common in notes.
final class FrontMatterBlock extends LeafBlock {
  FrontMatterBlock(super.lines);
}

/// A blank line, in the container whose content its own indent and
/// marks reach: there, text typed into it would go. An item's marker
/// line without content is one too.
final class BlankBlock extends LeafBlock {
  BlankBlock(super.lines);
}
