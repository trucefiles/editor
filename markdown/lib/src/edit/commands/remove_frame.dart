import 'package:collection/collection.dart';

import '../../tree/blocks.dart';
import '../../visible/visible_text.dart';
import '../../write/draft.dart';
import '../commit.dart';
import '../shown/rows.dart';
import '../shown/selection.dart';
import '../shown/shown_document.dart';
import '../shown/slot.dart';
import 'outline.dart';
import 'text_places.dart';

/// Backspace at the start of [slot], the first text of its innermost
/// item or quote: that frame goes. Out of a quote, the block (or gap)
/// goes one level out, the quote split around it. A first item's blocks
/// go above its list; another item's text becomes a line of the item
/// above, after a line break, its other blocks following there.
Edit removeFrame(ShownDocument document, Slot slot) {
  final caret = TextSelection.caret(Place(slot, 0));
  return switch (rowOfSlot(document, slot).path.lastOrNull) {
    final QuoteBlock quote => _outOfQuote(document, quote, slot),
    final ItemBlock item => switch (document.tree.parentOf(item)!
        as ListBlock) {
      final list when list.items.first == item => _aboveList(
        document,
        list,
        item,
      ),
      final list => _intoItemAbove(document, list, item, slot),
    },
    _ => Edit(selection: caret),
  };
}

/// Enter in [slot], the place of an empty item at a list's top level:
/// the item goes, and an empty paragraph shows where it was, between
/// the list's two parts (the file keeps one list until it gets text);
/// in place of the list if it was its only item.
Edit leaveList(ShownDocument document, Slot slot) {
  final item = document.tree.blockOf((slot as ItemSlot).item)! as ItemBlock;
  final list = document.tree.parentOf(item)! as ListBlock;
  if (list.items.length == 1) {
    // As a paragraph, so the list's container stays with it.
    final id = document.tree.freshBlockIds.first;
    return Edit(
      replaced: {
        list.id: [TextDraft(id, VisibleText.empty)],
      },
      selection: TextSelection.caret(Place(LeafSlot(id), 0)),
    );
  }
  final outer = document.tree.parentOf(list)!;
  final index = list.items.indexOf(item);
  final gap = switch (index) {
    0 => Gap(
      document.nextGap,
      container: outer.id,
      after: blockBefore(outer, list)?.id,
    ),
    _ when index == list.items.length - 1 => Gap(
      document.nextGap,
      container: outer.id,
      after: list.id,
    ),
    _ => Gap(
      document.nextGap,
      container: list.id,
      after: list.items[index - 1].id,
    ),
  };
  return Edit(
    replaced: {item.id: const []},
    gaps: withGap(document.gaps, gap, first: gap.after == list.id),
    nextGap: document.nextGap.next,
    selection: TextSelection.caret(Place(GapSlot(gap.id), 0)),
  );
}

/// [slot]'s block or gap one level out of [quote], which splits around
/// it: its first part keeps its id.
Edit _outOfQuote(ShownDocument document, QuoteBlock quote, Slot slot) {
  final tree = document.tree;
  final outer = tree.parentOf(quote)!;
  final children = quote.children;
  final (index, block, gap) = switch (slot) {
    LeafSlot(:final leaf) => (
      children.indexWhere((child) => child.id == leaf),
      tree.blockOf(leaf),
      null,
    ),
    GapSlot(gap: final id) => switch (document.gapOf(id)!) {
      final gap => (
        switch (gap.after) {
          null => 0,
          final after => children.indexWhere((child) => child.id == after) + 1,
        },
        null,
        gap,
      ),
    },
    ItemSlot() => throw ArgumentError.value(slot, 'slot', 'not in a quote'),
  };
  final before = children.take(index).toList();
  final after = children.skip(block == null ? index : index + 1).toList();
  // The first part keeps the quote's id and marks.
  final parts = [
    if (before.isNotEmpty) QuoteDraft.of(quote, kept(before)),
    ?block == null ? null : KeptDraft(block),
    if (after.isNotEmpty)
      before.isEmpty
          ? QuoteDraft.of(quote, kept(after))
          : QuoteDraft(tree.freshBlockIds.first, kept(after)),
  ];
  return Edit(
    replaced: {quote.id: parts},
    gaps: switch (gap) {
      null => null,
      final gap => [
        for (final other in document.gaps)
          if (other.id == gap.id)
            Gap(
              gap.id,
              container: outer.id,
              after: before.isEmpty ? blockBefore(outer, quote)?.id : quote.id,
            )
          else
            other,
      ],
    },
    selection: TextSelection.caret(Place(slot, 0)),
  );
}

/// [item], its list's first, gone: its blocks above [list], subitems
/// going on in the list where they are of its kind.
Edit _aboveList(ShownDocument document, ListBlock list, ItemBlock item) {
  final outer = document.tree.parentOf(list)!;
  final rest = list.items.skip(1).toList();
  final children = item.children;
  final (lifted, joins) = switch (children.lastOrNull) {
    final ListBlock last when last.kind == list.kind && rest.isNotEmpty => (
      children.take(children.length - 1).toList(),
      [...last.items, ...rest],
    ),
    _ => (children, rest),
  };
  // An item's own place, empty or before a frame, shows above it.
  final first = switch (children.firstOrNull) {
    final TextLeaf leaf => LeafSlot(leaf.id),
    final CodeBlock code => LeafSlot(code.id),
    _ => null,
  };
  final gap = Gap(
    document.nextGap,
    container: outer.id,
    after: blockBefore(outer, list)?.id,
  );
  return Edit(
    replaced: {
      list.id: [
        ...kept(lifted),
        if (joins.isNotEmpty) ListDraft.of(list, kept(joins)),
      ],
    },
    gaps: first == null ? withGap(document.gaps, gap, first: false) : null,
    nextGap: first == null ? document.nextGap.next : null,
    selection: TextSelection.caret(Place(first ?? GapSlot(gap.id), 0)),
  );
}

/// [item]'s text a line of the item above it in [list], after a line
/// break at the end of that item's last paragraph (a paragraph of its
/// own where the item ends otherwise); its other blocks follow there.
Edit _intoItemAbove(
  ShownDocument document,
  ListBlock list,
  ItemBlock item,
  Slot slot,
) {
  final above = list.items[list.items.indexOf(item) - 1];
  final text = document.textOf(slot);
  final first = item.children.firstOrNull;
  final (moved, rest) = switch (first) {
    final ParagraphBlock paragraph => (paragraph, item.children.skip(1)),
    _ => (null, item.children),
  };
  final last = above.children.lastOrNull;
  if (last is ParagraphBlock && (moved != null || first == null)) {
    final shown = document.textOf(LeafSlot(last.id));
    final joined = withText(
      document,
      LeafSlot(last.id),
      text.isEmpty ? shown : shown + VisibleText([HardBreakPiece()]) + text,
      document.tree.freshBlockIds.iterator,
      following: kept(rest),
      joined: [?moved],
    );
    return Edit(
      replaced: {item.id: const [], ...joined.replaced},
      selection: TextSelection.caret(
        Place(joined.slot, text.isEmpty ? shown.length : shown.length + 1),
      ),
    );
  }
  final rowAbove = document.rows[document.rowOf(slot)! - 1];
  return Edit(
    replaced: {
      item.id: const [],
      above.id: [
        ItemDraft.of(above, [...kept(above.children), ...kept(item.children)]),
      ],
    },
    selection: TextSelection.caret(switch ((first, rowAbove)) {
      (final TextLeaf leaf, _) => Place(LeafSlot(leaf.id), 0),
      (final CodeBlock code, _) => Place(LeafSlot(code.id), 0),
      (_, TextRow(slot: final above)) => Place(
        above,
        document.textOf(above).length,
      ),
      _ => Place(slot, 0),
    }),
  );
}
