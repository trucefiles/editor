/// What a block as read must keep to print its lines as read.
library;

import 'package:collection/collection.dart';

import '../doc/doc_nodes.dart';
import '../doc/origin.dart';
import '../document_tree.dart';
import '../read/document_reading.dart';
import '../tree/blocks.dart';
import '../tree/inlines.dart';
import '../visible/visible_text.dart';
import 'links.dart';

/// Whether [node] is still of the kind its source was read as.
bool kindKept(DocBlock node) => switch ((node, node.source)) {
  (ParagraphNode(), ParagraphBlock()) ||
  (HeadingNode(), HeadingBlock()) ||
  (CodeNode(), CodeBlock()) ||
  (DividerNode(), RuleBlock()) ||
  (TableNode(), TableBlock()) ||
  (RawNode(kind: RawKind.html), HtmlBlock()) ||
  (RawNode(kind: RawKind.definitions), DefinitionsBlock()) ||
  (RawNode(kind: RawKind.frontMatter), FrontMatterBlock()) ||
  (QuoteNode(), QuoteBlock()) ||
  (ListNode(), ListBlock()) ||
  (ItemNode(), ItemBlock()) => true,
  _ => false,
};

/// Whether [node] has a reference link or image that [definitions] no
/// longer resolve as read.
bool hasStaleReference(
  DocBlock node,
  Map<String, LinkDefinition> definitions,
) => leavesIn(node).whereType<TextNode>().any(
  (leaf) => leaf.text.pieces.any(
    (piece) =>
        switch (piece) {
          ObjectPiece(inline: final ImageInline image) => !imageResolves(
            image,
            definitions,
          ),
          _ => false,
        } ||
        switch (piece.formatting.link) {
          final link? => !linkResolves(link, definitions),
          null => false,
        },
  ),
);

/// Whether [source]'s lines, read in [markdown], keep their meaning under
/// new containers' marks: none is indented with a tab, none is a lazy
/// line, and its first line holds an item's marker exactly when it now
/// [startsItem].
bool linesTakeNewMarks(
  LeafBlock source,
  DocumentTree markdown, {
  required bool startsItem,
}) {
  final tabbed = source.lines.any(
    (line) =>
        line.tabColumns > 0 ||
        line.text
            .substring(0, line.text.length - line.text.trimLeft().length)
            .contains('\t'),
  );
  final marker = markdown
      .startsAt(source.lines.first.id)
      .any((PlacedBlock placed) => placed.block is ItemBlock);
  // A lazy line, missing its containers' marks, could read otherwise
  // with them (as a heading's underline).
  final lazy = source.lines.any(
    (line) => line.prefix.length < source.lines.first.prefix.length,
  );
  return !tabbed && !lazy && marker == startsItem;
}

/// Whether [source]'s first line, read in [origin], is indented in its
/// container.
bool indentedAsRead(Block source, Origin origin) {
  final leaf = source.leaves.firstOrNull;
  final line = leaf?.lines.first;
  if (line == null || line.id != lineSpanOf(source).first) return false;
  final ancestors = {
    for (final container in origin.placeOf(source)?.path ?? <Block>[])
      container.id,
  };
  final start = line.prefix
      .where((part) => ancestors.contains(part.container))
      .map((part) => part.end)
      .fold(0, (end, next) => next > end ? next : end);
  return line.text.startsWith(' ', start) || line.text.startsWith('\t', start);
}
