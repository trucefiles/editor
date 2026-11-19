import '../doc/doc_nodes.dart';
import '../doc/doc_tree.dart';
import '../doc/load.dart';
import '../print/links.dart';
import '../print/printer.dart';
import '../tree/inlines.dart';
import '../visible/visible_text.dart';

/// [text] with each inline image's destination changed as [relink] says
/// (`null`: kept), printed by the one printer, so every block whose
/// images keep their links keeps its bytes; `null` if none changes.
/// Reference images keep theirs: their destination is a definition's.
String? relinkedMarkdown(String text, String? Function(String) relink) {
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
VisibleText _relinked(VisibleText text, String? Function(String) relink) {
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
