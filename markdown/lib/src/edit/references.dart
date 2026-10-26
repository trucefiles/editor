import '../doc/doc_nodes.dart';
import '../doc/doc_tree.dart';
import '../read/syntax/characters.dart';
import '../read/syntax/link_syntax.dart';
import '../tree/blocks.dart';
import '../tree/inlines.dart';
import '../visible/formatting.dart';
import '../visible/visible_text.dart';

/// [doc] with each reference link and image leading where [definitions]
/// say its label leads; one whose label they do not define keeps leading
/// where it led.
DocTree withResolvedReferences(
  DocTree doc,
  Map<String, LinkDefinition> definitions,
) => nodesIn(doc.root).whereType<TextNode>().fold(doc, (doc, node) {
  final text = _resolved(node.text, definitions);
  return identical(text, node.text) ? doc : doc.withNode(node.withText(text));
});

/// [text] with its references resolved; the same object if none changes.
VisibleText _resolved(
  VisibleText text,
  Map<String, LinkDefinition> definitions,
) {
  LinkDefinition? definitionOf(ContainerInline reference) =>
      definitions[normalizeLabel(referenceLabel(reference))];
  final links = <LinkMark, LinkMark>{
    for (final piece in text.pieces)
      if (piece.formatting.link
          case LinkMark(read: final LinkInline read) && final mark
          when read.style == LinkStyle.reference)
        if (definitionOf(read) case final definition?
            when definition.destination != mark.destination ||
                (definition.title ?? '') != mark.title)
          mark: LinkMark(
            destination: definition.destination,
            title: definition.title ?? '',
            style: mark.style,
            read: read,
          ),
  };
  final images = <ImageInline, ImageInline>{
    for (final piece in text.pieces)
      if (piece case ObjectPiece(inline: final ImageInline image)
          when !image.close.startsWith(']('))
        if (definitionOf(image) case final definition?
            when definition.destination != image.destination ||
                (definition.title ?? '') != image.title)
          image: ImageInline(
            image.open,
            image.children,
            image.close,
            destination: definition.destination,
            title: definition.title ?? '',
          ),
  };
  if (links.isEmpty && images.isEmpty) return text;
  return VisibleText([
    for (final piece in text.pieces)
      switch (piece) {
        ObjectPiece(inline: final ImageInline image, :final formatting)
            when images.containsKey(image) =>
          ObjectPiece(images[image]!, _relinked(formatting, links)),
        _ => piece.withFormatting(_relinked(piece.formatting, links)),
      },
  ]);
}

Formatting _relinked(Formatting formatting, Map<LinkMark, LinkMark> links) =>
    switch (links[formatting.link]) {
      final link? => formatting.withLink(link),
      null => formatting,
    };
