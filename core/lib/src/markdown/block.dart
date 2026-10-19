import 'syntax/block_syntax.dart';

/// What an editor shows for one line of a document; library-neutral.
sealed class Block {
  const Block();
}

/// A list item of [kind], shown as its box, bullet or number with the text
/// after it.
final class ItemBlock extends Block {
  const ItemBlock({
    required this.kind,
    required this.depth,
    required this.text,
    this.checked = false,
  });

  final ListKind kind;

  /// Whether a checkbox's box is checked.
  final bool checked;

  /// Nesting level: 0 at the left margin.
  final int depth;

  /// The text after the marker, as in the file.
  final String text;
}

/// Any line, shown as its raw text.
final class TextBlock extends Block {
  const TextBlock(this.text);

  /// The whole line, as in the file.
  final String text;
}
