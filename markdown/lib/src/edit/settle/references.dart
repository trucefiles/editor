import '../../read/syntax/characters.dart';
import '../../tree/blocks.dart';
import '../../tree/inlines.dart';
import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';
import '../../write/inline/span_syntax.dart';

/// [text] with each reference link or image whose label [definitions] no
/// longer define (its definition went in the same edit) leading where it
/// led as an inline one.
VisibleText withDefinedReferences(
  VisibleText text,
  Map<String, LinkDefinition> definitions,
) {
  bool undefined(ContainerInline reference) =>
      !definitions.containsKey(normalizeLabel(_labelOf(reference)));
  final links = {
    for (final piece in text.pieces)
      if (piece.formatting.link
          case LinkMark(read: final LinkInline read) && final mark
          when read.style == LinkStyle.reference && undefined(read))
        mark: LinkMark(
          destination: mark.destination,
          title: mark.title,
          style: LinkStyle.inline,
        ),
  };
  return VisibleText([
    for (final piece in text.pieces)
      switch (piece) {
        ObjectPiece(inline: final ImageInline image, :final formatting)
            when !image.close.startsWith('](') && undefined(image) =>
          ObjectPiece(_inlineImage(image), _relinked(formatting, links)),
        _ => piece.withFormatting(_relinked(piece.formatting, links)),
      },
  ]);
}

Formatting _relinked(Formatting formatting, Map<LinkMark, LinkMark> links) =>
    switch (links[formatting.link]) {
      final link? => formatting.withLink(link),
      null => formatting,
    };

/// The label a reference link or image is defined by.
String _labelOf(ContainerInline reference) => switch (reference.close) {
  ']' || '][]' => reference.children.map((child) => child.source).join(),
  final close => close.substring(2, close.length - 1),
};

ImageInline _inlineImage(ImageInline image) => ImageInline(
  image.open,
  image.children,
  '](${destinationSource(image.destination)}${titleSource(image.title)})',
  destination: image.destination,
  title: image.title,
);
