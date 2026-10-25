import '../../tree/blocks.dart';
import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';
import '../../write/draft.dart';
import '../commit.dart';
import '../shown/selection.dart';
import '../shown/shown_document.dart';
import '../shown/slot.dart';
import 'outline.dart';
import 'text_commands.dart';

/// Enter at [at]: in an item's text, a new item after it with the text
/// after the caret and what followed in the item (at its very start, an
/// empty item above instead); in other text, a new paragraph (at the
/// very start, an empty one above instead); in code, a line break; in a
/// gap, another gap after it.
Edit splitBlock(ShownDocument document, Place at) {
  final tree = document.tree;
  final fresh = tree.freshBlockIds.iterator;
  BlockId next() => (fresh..moveNext()).current;
  switch (at.slot) {
    case LeafSlot(:final leaf):
      final block = tree.blockOf(leaf)!;
      if (block is CodeBlock) {
        return insertText(document, at, '\n', Formatting.plain);
      }
      final text = document.textOf(at.slot);
      final container = tree.parentOf(block)!;
      final atStart = at.offset == 0 && !text.isEmpty;
      return switch (container) {
        final ItemBlock item when atStart && item.children.first == block =>
          _itemAbove(document, item, next(), at),
        final ItemBlock item => _itemSplit(
          document,
          item,
          block as TextLeaf,
          at,
          text,
          next(),
          next(),
        ),
        _ when atStart => Edit(
          gaps: withGap(
            document.gaps,
            Gap(
              document.nextGap,
              container: container.id,
              after: blockBefore(container, block)?.id,
            ),
            first: false,
          ),
          nextGap: document.nextGap.next,
          selection: TextSelection.caret(at),
        ),
        _ => _paragraphSplit(block as TextLeaf, at, text, next()),
      };
    case ItemSlot(:final item):
      return _itemAbove(document, tree.blockOf(item)! as ItemBlock, next(), at);
    case GapSlot(:final gap):
      final shown = document.gapOf(gap)!;
      final added = Gap(
        document.nextGap,
        container: shown.container,
        after: shown.after,
      );
      final index = document.gaps.indexWhere((other) => other.id == gap);
      return Edit(
        gaps: [
          ...document.gaps.take(index + 1),
          added,
          ...document.gaps.skip(index + 1),
        ],
        nextGap: document.nextGap.next,
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
  ShownDocument document,
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
        ], checked: _newBox(document, item, at.slot)),
      ],
    },
    selection: TextSelection.caret(Place(LeafSlot(textId), 0)),
  );
}

/// An empty item above [item]; the caret stays.
Edit _itemAbove(ShownDocument document, ItemBlock item, BlockId id, Place at) =>
    Edit(
      replaced: {
        item.id: [
          ItemDraft(id, const [], checked: _newBox(document, item, at.slot)),
          KeptDraft(item),
        ],
      },
      selection: TextSelection.caret(at),
    );

/// The box of an item made from [item]'s row at [slot]: none if it has
/// none; checked in a Done section, else open.
bool? _newBox(ShownDocument document, ItemBlock item, Slot slot) =>
    item.hasBox ? rowOfSlot(document, slot).done : null;
