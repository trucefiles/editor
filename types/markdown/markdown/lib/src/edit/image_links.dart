/// The one rule for a document's image links, as read: what they lead
/// to, and changing where they lead.
library;

import '../doc/doc_nodes.dart';
import '../doc/doc_tree.dart';
import '../doc/load.dart';
import '../print/links.dart';
import '../print/printer.dart';
import '../tree/inlines.dart';
import '../visible/visible_text.dart';

/// How an image link changes: its new destination, `null` to keep it.
typedef Relink = String? Function(String destination);

/// Where every image of [doc] leads, inline and reference ones, in a
/// table's cells too; never a text that only looks like a link (e.g. in
/// code).
Set<String> imageLinksIn(DocTree doc) => {
  for (final node in nodesIn(doc.root))
    for (final text in _textsOf(node))
      for (final piece in text.pieces)
        if (piece case ObjectPiece(inline: final ImageInline image))
          image.destination,
};

/// The texts [node] shows with their images: its own, or a table's
/// cells.
Iterable<VisibleText> _textsOf(DocBlock node) => switch (node) {
  TextNode(:final text) => [text],
  TableNode(:final rows) => rows.expand((cells) => cells),
  _ => const [],
};

/// [imageLinksIn] the document [text] reads as.
Set<String> imageLinksOf(String text) => imageLinksIn(loadMarkdown(text).doc);

/// [text] with each inline image's destination changed as [relink] says,
/// printed by the one printer, so every block whose images keep their
/// links keeps its bytes; `null` if none changes. Reference images keep
/// theirs: their destination is a definition's.
String? relinkedMarkdown(String text, Relink relink) {
  final (:doc, :origin) = loadMarkdown(text);
  final changed = nodesIn(doc.root)
      .whereType<TextNode>()
      .fold<DocTree>(doc, (doc, node) {
        final relinked = _relinked(node.text, relink);
        return identical(relinked, node.text)
            ? doc
            : doc.withNode(node.withText(relinked));
      });
  return identical(changed, doc) ? null : printMarkdown(changed, origin).text;
}

/// [text] with its inline images relinked; the same object if none
/// changes.
VisibleText _relinked(VisibleText text, Relink relink) {
  final images = {
    for (final piece in text.pieces)
      if (piece case ObjectPiece(inline: final ImageInline image)
          when image.close.startsWith(']('))
        if (relink(image.destination) case final destination?)
          image: ImageInline(
            image.open,
            image.children,
            '](${destinationSource(destination)}${titleSource(image.title)})',
            destination: destination,
            title: image.title,
          ),
  };
  if (images.isEmpty) return text;
  return VisibleText([
    for (final piece in text.pieces)
      switch (piece) {
        ObjectPiece(inline: final ImageInline image, :final formatting)
            when images.containsKey(image) =>
          ObjectPiece(images[image]!, formatting),
        _ => piece,
      },
  ]);
}
