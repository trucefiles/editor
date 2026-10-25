import '../../tree/blocks.dart';
import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';
import '../../write/draft.dart';
import '../commit.dart';
import '../shown/selection.dart';
import '../shown/shown_note.dart';
import '../shown/slot.dart';
import 'outline.dart';
import 'text_commands.dart';

/// Enter at [at]: in an item's text, a new item after it with the text
/// after the caret and what followed in the item (at its very start, an
/// empty item above instead); in other text, a new paragraph (at the
/// very start, an empty one above instead); in code, a line break; in a
/// gap, another gap after it.
Edit splitBlock(ShownNote note, Place at) {
  final tree = note.tree;
  final fresh = tree.freshBlockIds.iterator;
  BlockId next() => (fresh..moveNext()).current;
  switch (at.slot) {
    case LeafSlot(:final leaf):
      final block = tree.blockOf(leaf)!;
      if (block is CodeBlock) {
        return insertText(note, at, '\n', Formatting.plain);
      }
      final text = note.textOf(at.slot);
      final container = tree.parentOf(block)!;
      final atStart = at.offset == 0 && !text.isEmpty;
      return switch (container) {
        final ItemBlock item when atStart && item.children.first == block =>
          _itemAbove(note, item, next(), at),
        final ItemBlock item => _itemSplit(
          note,
          item,
          block as TextLeaf,
          at,
          text,
          next(),
          next(),
        ),
        _ when atStart => Edit(
          gaps: withGap(
            note.gaps,
            Gap(
              note.nextGap,
              container: container.id,
              after: blockBefore(container, block)?.id,
            ),
            first: false,
          ),
          nextGap: note.nextGap.next,
          selection: TextSelection.caret(at),
        ),
        _ => _paragraphSplit(block as TextLeaf, at, text, next()),
      };
    case ItemSlot(:final item):
      return _itemAbove(note, tree.blockOf(item)! as ItemBlock, next(), at);
    case GapSlot(:final gap):
      final shown = note.gapOf(gap)!;
      final added = Gap(
        note.nextGap,
        container: shown.container,
        after: shown.after,
      );
      final index = note.gaps.indexWhere((other) => other.id == gap);
      return Edit(
        gaps: [
          ...note.gaps.take(index + 1),
          added,
          ...note.gaps.skip(index + 1),
        ],
        nextGap: note.nextGap.next,
        selection: TextSelection.caret(Place(GapSlot(added.id), 0)),
      );
  }
}

/// A new paragraph after [leaf] with its text after [at].
Edit _paragraphSplit(TextLeaf leaf, Place at, VisibleText text, BlockId id) =>
    Edit(
      replaced: {
        leaf.id: [
          TextDraft(
            leaf.id,
            text.slice(0, at.offset),
            level: leaf is HeadingBlock ? leaf.level : null,
            from: [leaf],
          ),
          TextDraft(id, text.slice(at.offset, text.length)),
        ],
      },
      selection: TextSelection.caret(Place(LeafSlot(id), 0)),
    );

/// A new item after [item] holding the text of [leaf] after [at] and
/// the blocks after [leaf]; open, or checked in a Done section.
Edit _itemSplit(
  ShownNote note,
  ItemBlock item,
  TextLeaf leaf,
  Place at,
  VisibleText text,
  BlockId itemId,
  BlockId textId,
) {
  final index = item.children.indexOf(leaf);
  return Edit(
    replaced: {
      item.id: [
        ItemDraft.of(item, [
          ...kept(item.children.take(index)),
          TextDraft(
            leaf.id,
            text.slice(0, at.offset),
            level: leaf is HeadingBlock ? leaf.level : null,
            from: [leaf],
          ),
        ]),
        ItemDraft(itemId, [
          TextDraft(textId, text.slice(at.offset, text.length)),
          ...kept(item.children.skip(index + 1)),
        ], checked: _newBox(note, item, at.slot)),
      ],
    },
    selection: TextSelection.caret(Place(LeafSlot(textId), 0)),
  );
}

/// An empty item above [item]; the caret stays.
Edit _itemAbove(ShownNote note, ItemBlock item, BlockId id, Place at) => Edit(
  replaced: {
    item.id: [
      ItemDraft(id, const [], checked: _newBox(note, item, at.slot)),
      KeptDraft(item),
    ],
  },
  selection: TextSelection.caret(at),
);

/// The box of an item made from [item]'s row at [slot]: none if it has
/// none; checked in a Done section, else open.
bool? _newBox(ShownNote note, ItemBlock item, Slot slot) =>
    item.hasBox ? rowOfSlot(note, slot).done : null;
