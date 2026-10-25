import '../../tree/blocks.dart';

/// Identifies a gap while it shows. Opaque: only equal or not.
extension type const GapId._(int _value) {
  /// The gap that shows after a document's last block when that has no text
  /// (or the document has no block), so there is a place to type after it.
  static const end = GapId._(0);

  /// The first id of a document's other gaps.
  static const first = GapId._(1);

  /// The id after this one.
  GapId get next => GapId._(_value + 1);
}

/// A place in Visual edit that shows text and takes the caret.
sealed class Slot {
  const Slot();
}

/// A paragraph, heading or code block.
final class LeafSlot extends Slot {
  const LeafSlot(this.leaf);

  final BlockId leaf;

  @override
  bool operator ==(Object other) => other is LeafSlot && other.leaf == leaf;

  @override
  int get hashCode => Object.hash(LeafSlot, leaf);

  @override
  String toString() => 'LeafSlot($leaf)';
}

/// The text place of an item without text of its own at its start: an
/// empty item, or one whose first block is a list. It writes the item's
/// first paragraph once it gets text.
final class ItemSlot extends Slot {
  const ItemSlot(this.item);

  final BlockId item;

  @override
  bool operator ==(Object other) => other is ItemSlot && other.item == item;

  @override
  int get hashCode => Object.hash(ItemSlot, item);

  @override
  String toString() => 'ItemSlot($item)';
}

/// A gap: an empty paragraph that shows but is in the file only once it
/// gets text (Markdown has no empty paragraph).
final class GapSlot extends Slot {
  const GapSlot(this.gap);

  final GapId gap;

  @override
  bool operator ==(Object other) => other is GapSlot && other.gap == gap;

  @override
  int get hashCode => Object.hash(GapSlot, gap);

  @override
  String toString() => 'GapSlot($gap)';
}

/// Where a gap shows: in [container] (the root, a quote or an item) right
/// after its child [after], or first if `null`. A gap in a list shows
/// between its items, where writing it splits the list.
final class Gap {
  const Gap(this.id, {required this.container, this.after});

  final GapId id;
  final BlockId container;
  final BlockId? after;

  /// This gap shown after [after] instead.
  Gap movedAfter(BlockId? after) => Gap(id, container: container, after: after);

  @override
  String toString() => 'Gap($id in $container after $after)';
}
