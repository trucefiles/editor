/// The text places of a document tree: what each shows, and the leaf it
/// becomes with other text.
library;

import '../doc/doc_nodes.dart';
import '../doc/doc_tree.dart';
import '../view/rows.dart';
import '../visible/visible_text.dart';
import 'autolinks.dart';

/// The text the text place [leaf] of [doc] shows.
VisibleText textAt(DocTree doc, NodeId leaf) =>
    textOf(doc.nodeOf(leaf)! as DocLeaf);

/// [leaf] showing [text]: a text node's text with the links its text
/// makes (see `withAutolinks`, `withAngleAutolinks`), code as plain text.
DocLeaf withLeafText(DocLeaf leaf, VisibleText text) => switch (leaf) {
  TextNode() => leaf.withText(
    withAutolinks(withAngleAutolinks(text), was: leaf.text),
  ),
  CodeNode() => leaf.withCode(text.text),
  _ => throw ArgumentError.value(leaf, 'leaf', 'no text place'),
};

/// [doc] with the text place [leaf] showing [text].
DocTree withTextAt(DocTree doc, NodeId leaf, VisibleText text) =>
    doc.withNode(withLeafText(doc.nodeOf(leaf)! as DocLeaf, text));
