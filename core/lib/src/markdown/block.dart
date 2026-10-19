/// What an editor shows for one line of a document; library-neutral.
sealed class Block {
  const Block();
}

/// A checkbox item, shown as a box with the text after it.
final class ItemBlock extends Block {
  const ItemBlock({
    required this.checked,
    required this.depth,
    required this.text,
  });

  final bool checked;

  /// Nesting level: 0 at the left margin.
  final int depth;

  /// The text after the box, as in the file.
  final String text;
}

/// Any line, shown as its raw text.
final class TextBlock extends Block {
  const TextBlock(this.text);

  /// The whole line, as in the file.
  final String text;
}
