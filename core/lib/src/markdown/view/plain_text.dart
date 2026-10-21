import '../document/markdown_document.dart';
import '../tree/blocks.dart';
import 'leaf_markup.dart';
import 'shown_text.dart';

/// A document's text as plain words, e.g. for a title or a preview.
extension PlainText on MarkdownDocument {
  /// The words of [leaf] as it shows formatted: text without its marks
  /// and images, code without its fences, a table's cells row by row;
  /// empty for blocks without words (rules, front matter, definitions).
  String plainTextOf(LeafBlock leaf) => switch (leaf) {
    CodeBlock(:final codeLines) =>
      codeLines.map((line) => line.content).join('\n'),
    TableBlock(:final rows) => rows.map((row) => row.join(' ')).join('\n'),
    RuleBlock() || FrontMatterBlock() || DefinitionsBlock() => '',
    _ => ShownText.of(
      leaf.text,
      leafMarkup(
        leaf.text,
        LeafKind.of(leaf),
        leaf: leaf,
        definitions: definitions,
      ),
    ).text.replaceAll(_image, ''),
  };
}

/// The character an image shows as (see `ImageMarkup`).
const _image = '￼';
