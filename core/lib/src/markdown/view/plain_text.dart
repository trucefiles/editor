import '../document/markdown_document.dart';
import '../tree/blocks.dart';
import 'leaf_markup.dart';
import 'shown_text.dart';

/// A document's text as plain words, e.g. for a title or a preview.
extension PlainText on MarkdownDocument {
  /// The text of [leaf] as it shows formatted, without its marks and
  /// images.
  String plainTextOf(LeafBlock leaf) => ShownText.of(
    leaf.text,
    leafMarkup(
      leaf.text,
      LeafKind.of(leaf),
      leaf: leaf,
      definitions: definitions,
    ),
  ).text.replaceAll(_image, '');
}

/// The character an image shows as (see `ImageMarkup`).
const _image = '￼';
