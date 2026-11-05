import '../doc/doc_nodes.dart';

/// A caret place: [offset] in the text of the text place [leaf].
final class Place {
  const Place(this.leaf, this.offset);

  final NodeId leaf;
  final int offset;

  @override
  bool operator ==(Object other) =>
      other is Place && other.leaf == leaf && other.offset == offset;

  @override
  int get hashCode => Object.hash(leaf, offset);

  @override
  String toString() => 'Place($leaf, $offset)';
}

/// What is selected in Visual edit.
sealed class Selection {
  const Selection();

  /// The leaf it ends on, where the caret shows.
  NodeId get endLeaf => switch (this) {
    TextSelection(:final extent) => extent.leaf,
    BlockCaret(:final block) || BlockSelection(:final block) => block,
  };
}

/// Text from [base], where the selection started, to [extent], where it
/// ends now: a caret where both are the same.
final class TextSelection extends Selection {
  const TextSelection(this.base, this.extent);

  const TextSelection.caret(Place place) : this(place, place);

  final Place base;
  final Place extent;

  bool get isCaret => base == extent;

  @override
  bool operator ==(Object other) =>
      other is TextSelection && other.base == base && other.extent == extent;

  @override
  int get hashCode => Object.hash(base, extent);

  @override
  String toString() =>
      isCaret ? 'Caret($base)' : 'TextSelection($base, $extent)';
}

/// The caret right after [block], a block without text (a divider), as
/// after one character: typing or Enter starts a new line after it,
/// Backspace removes it.
final class BlockCaret extends Selection {
  const BlockCaret(this.block);

  final NodeId block;

  @override
  bool operator ==(Object other) => other is BlockCaret && other.block == block;

  @override
  int get hashCode => Object.hash(BlockCaret, block);

  @override
  String toString() => 'BlockCaret($block)';
}

/// A block without text, selected whole: a divider.
final class BlockSelection extends Selection {
  const BlockSelection(this.block);

  final NodeId block;

  @override
  bool operator ==(Object other) =>
      other is BlockSelection && other.block == block;

  @override
  int get hashCode => Object.hash(BlockSelection, block);

  @override
  String toString() => 'BlockSelection($block)';
}
