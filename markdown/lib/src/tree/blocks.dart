/// The blocks of a document as CommonMark 0.31 and GitHub Flavored Markdown
/// read them: containers that hold blocks, and leaves that hold lines.
/// Immutable values without parent links, so an edit rebuilds only the
/// path to what it changed; `DocumentTree` answers questions about where a
/// block is. Blank lines are no blocks: they are layout between leaves.
library;

import 'package:truce_core/truce_core.dart' show LineId;

import 'inlines.dart';

/// Identifies a block while it lives, across edits of its lines.
/// Opaque: only equal or not.
extension type const BlockId(int _value) {}

/// One block.
sealed class Block {
  const Block(this.id);

  final BlockId id;

  /// The leaves in it, in file order: itself for a leaf.
  Iterable<LeafBlock> get leaves;
}

/// A block that holds blocks, in file order.
sealed class ContainerBlock extends Block {
  ContainerBlock(super.id, List<Block> children)
    : children = List.unmodifiable(children);

  final List<Block> children;

  @override
  Iterable<LeafBlock> get leaves => children.expand((child) => child.leaves);

  /// This container with [children] instead.
  ContainerBlock withChildren(List<Block> children);
}

/// The whole document.
final class RootBlock extends ContainerBlock {
  RootBlock(super.id, super.children);

  @override
  RootBlock withChildren(List<Block> children) => RootBlock(id, children);
}

/// A block quote: the lines it spans and the blocks in it. A quote of
/// only `>` lines holds no blocks.
final class QuoteBlock extends ContainerBlock {
  QuoteBlock(
    super.id,
    super.children, {
    required this.firstLine,
    required this.lastLine,
  });

  /// The line it starts at.
  final LineId firstLine;

  /// The last line that goes on with it, `>` lines after its last block
  /// included.
  final LineId lastLine;

  @override
  QuoteBlock withChildren(List<Block> children) =>
      QuoteBlock(id, children, firstLine: firstLine, lastLine: lastLine);
}

/// The kinds of lists. Whether an item has a box is the item's own.
enum ListKind { bullet, numbered }

/// How a numbered list counts.
enum Numbering {
  /// `1. 2. 3.`: each item one more than the one before.
  sequential,

  /// `1. 1. 1.`: every item the same number.
  same,
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

  ListKind get kind => number == null ? ListKind.bullet : ListKind.numbered;

  /// Whether an item with [other] continues the same list: the same
  /// bullet character, or numbers with the same delimiter.
  bool sameListAs(ItemMarker other) => kind == ListKind.numbered
      ? other.delimiter == delimiter
      : other.bullet == bullet;

  @override
  bool operator ==(Object other) =>
      other is ItemMarker &&
      other.bullet == bullet &&
      other.number == number &&
      other.delimiter == delimiter;

  @override
  int get hashCode => Object.hash(bullet, number, delimiter);

  @override
  String toString() => bullet ?? '$number$delimiter';
}

/// A list: items of one kind of marker (see [ItemMarker.sameListAs]).
final class ListBlock extends ContainerBlock {
  ListBlock(super.id, List<ItemBlock> super.children, {required this.loose});

  /// Whether blank lines separate its items or the blocks in them.
  final bool loose;

  List<ItemBlock> get items => children.cast<ItemBlock>();

  ListKind get kind => items.first.marker.kind;

  /// How it counts; a bullet list counts [Numbering.sequential].
  late final Numbering numbering =
      kind == ListKind.numbered &&
          items.length > 1 &&
          items.map((item) => item.marker.number).toSet().length == 1
      ? Numbering.same
      : Numbering.sequential;

  @override
  ListBlock withChildren(List<Block> children) =>
      ListBlock(id, children.cast<ItemBlock>(), loose: loose);
}

/// A list item: its marker line and the blocks in it. An empty item
/// holds no blocks.
final class ItemBlock extends ContainerBlock {
  ItemBlock(
    super.id,
    super.children, {
    required this.markerLine,
    required this.marker,
    required this.checked,
    required this.markerColumn,
    required this.contentColumn,
  });

  /// The line its marker is on.
  final LineId markerLine;

  final ItemMarker marker;

  /// Whether its box is checked; `null` if it has none.
  final bool? checked;

  /// The column its marker starts at, from where its container's content
  /// starts.
  final int markerColumn;

  /// The column its content starts at, from where its container's
  /// content starts: lines in it are indented at least this far.
  final int contentColumn;

  bool get hasBox => checked != null;

  bool get isEmpty => children.isEmpty;

  @override
  ItemBlock withChildren(List<Block> children) => ItemBlock(
    id,
    children,
    markerLine: markerLine,
    marker: marker,
    checked: checked,
    markerColumn: markerColumn,
    contentColumn: contentColumn,
  );
}

/// A container's part of one line: its `>`, or an item's marker or
/// indent; from [start] to [end] in the line.
typedef PrefixPart = ({BlockId container, int start, int end});

/// One line of a leaf: its containers' parts ([prefix]), and the leaf's
/// own part, from [contentStart] on.
final class SourceLine {
  SourceLine(
    this.id,
    this.text, {
    required List<PrefixPart> prefix,
    required this.contentStart,
    this.tabColumns = 0,
  }) : prefix = List.unmodifiable(prefix);

  final LineId id;

  /// The whole line, as in the file.
  final String text;

  /// The containers' parts, outermost first. A lazy line lacks the parts
  /// of the containers it continues without their marks.
  final List<PrefixPart> prefix;

  /// Where the leaf's part starts.
  final int contentStart;

  /// Columns of a tab right before [contentStart] that its containers
  /// took only in part: in a code block they show as spaces.
  final int tabColumns;

  /// The leaf's part of the line.
  String get content => text.substring(contentStart);
}

/// A block that holds lines and no blocks.
sealed class LeafBlock extends Block {
  LeafBlock(super.id, List<SourceLine> lines)
    : lines = List.unmodifiable(lines);

  /// Its lines, in file order; at least one.
  final List<SourceLine> lines;

  @override
  Iterable<LeafBlock> get leaves => [this];

  /// Its lines' parts, joined by line breaks.
  late final String content = lines.map((line) => line.content).join('\n');
}

/// A leaf whose content is inline text: a paragraph or heading.
sealed class TextLeaf extends LeafBlock {
  TextLeaf(super.id, super.lines, this.text);

  /// Its inline content; its source is [content].
  final InlineText text;
}

/// Text.
final class ParagraphBlock extends TextLeaf {
  ParagraphBlock(super.id, super.lines, super.text);
}

/// How a heading is written.
enum HeadingStyle {
  /// `# Title`.
  atx,

  /// `Title` over a line of `=` or `-`.
  setext,
}

/// A heading of [level] 1 to 6.
final class HeadingBlock extends TextLeaf {
  HeadingBlock(
    super.id,
    super.lines,
    super.text, {
    required this.level,
    required this.style,
  });

  final int level;
  final HeadingStyle style;
}

/// A code block: fenced, with its fences as its first and (if [closed])
/// last line, or indented.
final class CodeBlock extends LeafBlock {
  CodeBlock(
    super.id,
    super.lines, {
    required this.fence,
    required this.closed,
    this.info = '',
  });

  /// Its opening fence (e.g. ```` ``` ````); `null` if indented.
  final String? fence;

  /// Whether a fenced block has its closing fence.
  final bool closed;

  /// The info string after the opening fence, unescaped.
  final String info;

  bool get fenced => fence != null;

  /// The lines of code, without fences.
  List<SourceLine> get codeLines => fenced
      ? lines.sublist(1, closed ? lines.length - 1 : lines.length)
      : lines;

  /// The code as it shows: its lines with the spaces of split tabs.
  late final String code = codeLines
      .map((line) => '${' ' * line.tabColumns}${line.content}')
      .join('\n');
}

/// A block of HTML, kept as written.
final class HtmlBlock extends LeafBlock {
  HtmlBlock(super.id, super.lines);
}

/// How a table column's cells line up.
enum CellAlignment { none, left, center, right }

/// A table: its header row, delimiter row, and body rows.
final class TableBlock extends LeafBlock {
  TableBlock(
    super.id,
    super.lines, {
    required List<CellAlignment> alignments,
    required List<List<InlineText>> rows,
  }) : alignments = List.unmodifiable(alignments),
       rows = List.unmodifiable(rows.map(List<InlineText>.unmodifiable));

  final List<CellAlignment> alignments;

  /// The cells of the header row and then each body row, as many as
  /// [alignments]; a missing cell is empty.
  final List<List<InlineText>> rows;
}

/// A thematic break: `---`, `***` or `___`.
final class RuleBlock extends LeafBlock {
  RuleBlock(super.id, super.lines);
}

/// A link reference definition: `[label]: destination "title"`.
typedef LinkDefinition = ({String label, String destination, String? title});

/// Lines of link reference definitions.
final class DefinitionsBlock extends LeafBlock {
  DefinitionsBlock(super.id, super.lines, List<LinkDefinition> definitions)
    : definitions = List.unmodifiable(definitions);

  final List<LinkDefinition> definitions;
}

/// Front matter: lines between `---` lines at the very top of a document.
/// Not CommonMark, but common in documents.
final class FrontMatterBlock extends LeafBlock {
  FrontMatterBlock(super.id, super.lines);
}

/// The ids of [block] and every block in it.
Iterable<BlockId> idsIn(Block block) => switch (block) {
  ContainerBlock(:final children) => [block.id, ...children.expand(idsIn)],
  LeafBlock() => [block.id],
};

/// The lines [block] spans, as ids, first and last: from where it starts
/// (an item at its marker) to its last block's last line; a quote spans
/// its `>` lines. Not for an empty root.
({LineId first, LineId last}) lineSpanOf(Block block) => switch (block) {
  ItemBlock(:final markerLine, :final children) => (
    first: markerLine,
    last: children.isEmpty ? markerLine : lineSpanOf(children.last).last,
  ),
  QuoteBlock(:final firstLine, :final lastLine) => (
    first: firstLine,
    last: lastLine,
  ),
  ContainerBlock(:final children) => (
    first: lineSpanOf(children.first).first,
    last: lineSpanOf(children.last).last,
  ),
  LeafBlock(:final lines) => (first: lines.first.id, last: lines.last.id),
};
