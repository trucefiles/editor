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
