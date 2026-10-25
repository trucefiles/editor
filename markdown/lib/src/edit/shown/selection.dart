import '../../tree/blocks.dart';
import 'slot.dart';

/// A caret place: [offset] in the text [slot] shows.
final class Place {
  const Place(this.slot, this.offset);

  final Slot slot;
  final int offset;

  @override
  bool operator ==(Object other) =>
      other is Place && other.slot == slot && other.offset == offset;

  @override
  int get hashCode => Object.hash(slot, offset);

  @override
  String toString() => 'Place($slot, $offset)';
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

  /// This selection with the slots [moved] maps moved there.
  TextSelection movedBy(Map<Slot, Slot> moved) => TextSelection(
    Place(moved[base.slot] ?? base.slot, base.offset),
    Place(moved[extent.slot] ?? extent.slot, extent.offset),
  );

  @override
  bool operator ==(Object other) =>
      other is TextSelection && other.base == base && other.extent == extent;

  @override
  int get hashCode => Object.hash(base, extent);

  @override
  String toString() =>
      isCaret ? 'Caret($base)' : 'TextSelection($base, $extent)';
}

/// A block without text, selected whole: a rule.
final class BlockSelection extends Selection {
  const BlockSelection(this.block);

  final BlockId block;

  @override
  bool operator ==(Object other) =>
      other is BlockSelection && other.block == block;

  @override
  int get hashCode => Object.hash(BlockSelection, block);

  @override
  String toString() => 'BlockSelection($block)';
}
