import '../document_tree.dart';
import '../tree/blocks.dart';
import '../visible/visible_text.dart';
import 'doc_nodes.dart';
import 'doc_tree.dart';
import 'normalized.dart';
import 'origin.dart';

/// A document read from its text: the tree Visual edit shows, and where it
/// came from.
typedef Loaded = ({DocTree doc, Origin origin});

/// The document [text] holds, as Markdown.
Loaded loadMarkdown(String text) {
  final markdown = DocumentTree.read(text);
  final fresh = FreshIds(0);
  final mapped = DocTree(
    _Mapper(fresh, (block) => block).root(markdown.root),
    nextId: fresh.next,
  );
  final doc = normalized(mapped, fresh);
  return (doc: doc, origin: Origin(markdown, nodesIn(doc.root)));
}

/// The blocks [text] reads as in Markdown, as new document blocks: ids
/// from [fresh], read from no document, so printed anew.
List<DocBlock> newBlocksOf(String text, FreshIds fresh) {
  final mapper = _Mapper(fresh, (_) => null);
  return [
    for (final block in DocumentTree.read(text).root.children)
      mapper.block(block),
  ];
}

final class _Mapper {
  _Mapper(this._fresh, this._source);

  final FreshIds _fresh;

  /// The source a node read from a block keeps.
  final Block? Function(Block block) _source;

  DocRoot root(RootBlock root) =>
      DocRoot(_fresh.take(), _blocks(root.children), source: _source(root));

  List<DocBlock> _blocks(List<Block> blocks) => [
    for (final block in blocks) this.block(block),
  ];

  DocBlock block(Block block) => switch (block) {
    RootBlock() => throw ArgumentError.value(block, 'block', 'a root inside'),
    QuoteBlock(:final children) => QuoteNode(
      _fresh.take(),
      children.isEmpty ? [emptyParagraph(_fresh)] : _blocks(children),
      source: _source(block),
    ),
    ListBlock(:final items) => ListNode(
      _fresh.take(),
      [for (final item in items) _item(item)],
      kind: block.kind,
      numbering: block.numbering,
      start: items.first.marker.number ?? 1,
      source: _source(block),
    ),
    ItemBlock() => _item(block),
    ParagraphBlock(:final text) => ParagraphNode(
      _fresh.take(),
      visibleTextOf(text),
      source: _source(block),
    ),
    HeadingBlock(:final text, :final level) => HeadingNode(
      _fresh.take(),
      visibleTextOf(text),
      level: level,
      source: _source(block),
    ),
    CodeBlock(:final code, :final info) => CodeNode(
      _fresh.take(),
      code,
      info: info,
      source: _source(block),
    ),
    RuleBlock() => DividerNode(_fresh.take(), source: _source(block)),
    TableBlock(:final alignments, :final rows) => TableNode(
      _fresh.take(),
      _unindented(block.content),
      alignments: alignments,
      rows: [
        for (final row in rows) [for (final cell in row) visibleTextOf(cell)],
      ],
      source: _source(block),
    ),
    HtmlBlock() => RawNode(
      _fresh.take(),
      _unindented(block.content),
      kind: RawKind.html,
      source: _source(block),
    ),
    DefinitionsBlock() => RawNode(
      _fresh.take(),
      _unindented(block.content),
      kind: RawKind.definitions,
      source: _source(block),
    ),
    FrontMatterBlock() => RawNode(
      _fresh.take(),
      _unindented(block.content),
      kind: RawKind.frontMatter,
      source: _source(block),
    ),
  };

  ItemNode _item(ItemBlock item) => ItemNode(
    _fresh.take(),
    _blocks(item.children),
    checked: item.checked,
    source: _source(item),
  );
}

/// [content] of a raw block without its first line's indent, which no
/// raw block's meaning depends on (it decides only whether the block
/// joins an item above).
String _unindented(String content) => content.replaceFirst(RegExp('^ +'), '');
