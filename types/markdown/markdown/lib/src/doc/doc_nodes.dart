/// Markdown's editing tree, the one Visual edit works on: what a document
/// holds, as blocks, lists and inline text. Commands change only this
/// tree; the printer turns it into Markdown text. Immutable values
/// without parent links, so an edit rebuilds only the path to what it
/// changed; `DocTree` answers where a node is. Nodes keep the Markdown
/// they were read from (a block's source, a link's or an object's inline)
/// and use Markdown's list kinds and numbering, so the tree belongs to
/// Markdown, not to every format.
library;

import '../tree/blocks.dart';
import '../visible/visible_text.dart';

/// Identifies a node of a document tree while it lives. Opaque: only
/// equal or not.
extension type const NodeId(int _value) {}

/// One block of a document.
sealed class DocBlock {
  const DocBlock(this.id, {this.source});

  final NodeId id;

  /// The Markdown block it was read from; `null` for a new block.
  final Block? source;
}

/// A block that holds blocks, in order.
sealed class DocContainer extends DocBlock {
  DocContainer(super.id, List<DocBlock> children, {super.source})
    : children = List.unmodifiable(children);

  final List<DocBlock> children;

  /// This container with [children] instead.
  DocContainer withChildren(List<DocBlock> children);
}

/// The whole document.
final class DocRoot extends DocContainer {
  DocRoot(super.id, super.children, {super.source});

  @override
  DocRoot withChildren(List<DocBlock> children) =>
      DocRoot(id, children, source: source);
}

/// A quote.
final class QuoteNode extends DocContainer {
  QuoteNode(super.id, super.children, {super.source});

  @override
  QuoteNode withChildren(List<DocBlock> children) =>
      QuoteNode(id, children, source: source);
}

/// A list: items of one [kind], numbered from [start] as [numbering] says
/// if numbered.
final class ListNode extends DocContainer {
  ListNode(
    super.id,
    List<ItemNode> super.children, {
    required this.kind,
    this.numbering = Numbering.sequential,
    this.start = 1,
    super.source,
  });

  final ListKind kind;
  final Numbering numbering;
  final int start;

  List<ItemNode> get items => children.cast<ItemNode>();

  /// The number the item at [index] shows; `null` in a bullet list.
  int? numberAt(int index) => switch ((kind, numbering)) {
    (ListKind.bullet, _) => null,
    (ListKind.numbered, Numbering.same) => start,
    (ListKind.numbered, Numbering.sequential) => start + index,
  };

  @override
  ListNode withChildren(List<DocBlock> children) => ListNode(
    id,
    children.cast<ItemNode>(),
    kind: kind,
    numbering: numbering,
    start: start,
    source: source,
  );

  /// This list with its items of [kind] instead, numbered from 1.
  ListNode withKind(ListKind kind) => ListNode(
    id,
    items,
    kind: kind,
    start: kind == this.kind ? start : 1,
    numbering: kind == this.kind ? numbering : Numbering.sequential,
    source: source,
  );
}

/// A list item, with a box if [checked] is not `null`.
final class ItemNode extends DocContainer {
  ItemNode(super.id, super.children, {this.checked, super.source});

  /// Whether its box is checked; `null` if it has none.
  final bool? checked;

  bool get hasBox => checked != null;

  @override
  ItemNode withChildren(List<DocBlock> children) =>
      ItemNode(id, children, checked: checked, source: source);

  /// This item with its box [checked] (`null` for none).
  ItemNode withBox(bool? checked) =>
      ItemNode(id, children, checked: checked, source: source);
}

/// A block that holds no blocks.
sealed class DocLeaf extends DocBlock {
  const DocLeaf(super.id, {super.source});
}

/// A leaf of formatted text: a paragraph or heading.
sealed class TextNode extends DocLeaf {
  const TextNode(super.id, this.text, {super.source});

  final VisibleText text;

  /// This node with [text] instead.
  TextNode withText(VisibleText text);
}

/// Text.
final class ParagraphNode extends TextNode {
  const ParagraphNode(super.id, super.text, {super.source});

  @override
  ParagraphNode withText(VisibleText text) =>
      ParagraphNode(id, text, source: source);
}

/// A heading of [level] 1 to 6.
final class HeadingNode extends TextNode {
  const HeadingNode(super.id, super.text, {required this.level, super.source});

  final int level;

  @override
  HeadingNode withText(VisibleText text) =>
      HeadingNode(id, text, level: level, source: source);
}

/// Code, as it shows: its lines joined by `\n`; [info] says its language.
final class CodeNode extends DocLeaf {
  const CodeNode(super.id, this.code, {this.info = '', super.source});

  final String code;
  final String info;

  /// This node with [code] instead.
  CodeNode withCode(String code) =>
      CodeNode(id, code, info: info, source: source);
}

/// A thematic break: a line across.
final class DividerNode extends DocLeaf {
  const DividerNode(super.id, {super.source});
}

/// A block edited as its raw text, lines joined by `\n`, and kept as
/// written.
sealed class RawLeaf extends DocLeaf {
  const RawLeaf(super.id, this.raw, {super.source});

  final String raw;

  /// This block with [raw] instead.
  RawLeaf withRaw(String raw);
}

/// A table: its raw text, and its rows as they show, for drawing only.
final class TableNode extends RawLeaf {
  TableNode(
    super.id,
    super.raw, {
    required List<CellAlignment> alignments,
    required List<List<VisibleText>> rows,
    super.source,
  }) : alignments = List.unmodifiable(alignments),
       rows = List.unmodifiable(rows.map(List<VisibleText>.unmodifiable));

  final List<CellAlignment> alignments;

  /// The header row's cells and then each body row's, as many as
  /// [alignments].
  final List<List<VisibleText>> rows;

  @override
  TableNode withRaw(String raw) =>
      TableNode(id, raw, alignments: alignments, rows: rows, source: source);
}

/// The kinds of raw blocks besides tables.
enum RawKind {
  /// A block of HTML.
  html,

  /// Link reference definitions.
  definitions,

  /// Front matter at the top of a document.
  frontMatter,
}

/// A block of HTML, link definitions or front matter.
final class RawNode extends RawLeaf {
  const RawNode(super.id, super.raw, {required this.kind, super.source});

  final RawKind kind;

  @override
  RawNode withRaw(String raw) => RawNode(id, raw, kind: kind, source: source);
}

/// [block] and every node in it, outermost first.
Iterable<DocBlock> nodesIn(DocBlock block) => switch (block) {
  DocContainer(:final children) => [block, ...children.expand(nodesIn)],
  DocLeaf() => [block],
};

/// The leaves in [block], in order.
Iterable<DocLeaf> leavesIn(DocBlock block) => switch (block) {
  DocContainer(:final children) => children.expand(leavesIn),
  final DocLeaf leaf => [leaf],
};
