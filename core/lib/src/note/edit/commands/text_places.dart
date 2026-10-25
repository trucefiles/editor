import '../../tree/blocks.dart';
import '../../visible/visible_text.dart';
import '../../write/draft.dart';
import '../settle/whitespace.dart';
import '../shown/shown_note.dart';
import '../shown/slot.dart';

/// What a text place showing new text changes: the blocks it [replaced],
/// the [gaps] if they change, the [tails] of places that write nothing,
/// and the [slot] the text shows in after.
typedef TextChange = ({
  Map<BlockId, List<Draft>> replaced,
  List<Gap>? gaps,
  Map<Slot, VisibleText> tails,
  Slot slot,
});

/// The change that makes [slot] of [note] show [text], with [following]
/// drafts right after it: a leaf takes the text (spelled as it or the
/// leaves [joined] to it were); an item's own place or a gap writes a
/// new paragraph once its text is one a leaf can hold (or once blocks
/// follow it, or it is a heading), taking an id from [fresh]; a gap in
/// a list then splits the list around it. Until then they only show it.
/// The text is a heading of [heading]'s level if given (`null` for a
/// paragraph), else of the leaf's.
TextChange withText(
  ShownNote note,
  Slot slot,
  VisibleText text,
  Iterator<BlockId> fresh, {
  List<Draft> following = const [],
  List<TextLeaf> joined = const [],
  ({int? level})? heading,
}) {
  final tree = note.tree;
  final level = heading?.level;
  if (slot is! LeafSlot &&
      following.isEmpty &&
      level == null &&
      withoutTail(text).text.isEmpty) {
    return (replaced: const {}, gaps: null, tails: {slot: text}, slot: slot);
  }
  BlockId next() => (fresh..moveNext()).current;
  switch (slot) {
    case LeafSlot(:final leaf):
      return (
        replaced: {
          leaf: [
            switch (tree.blockOf(leaf)) {
              final TextLeaf old => TextDraft(
                leaf,
                text,
                level: heading == null
                    ? (old is HeadingBlock ? old.level : null)
                    : level,
                from: [old, ...joined],
              ),
              final CodeBlock old => CodeDraft(old, text.text),
              final block => throw ArgumentError.value(
                block,
                'slot',
                'no text',
              ),
            },
            ...following,
          ],
        },
        gaps: null,
        tails: const {},
        slot: slot,
      );
    case ItemSlot(:final item):
      final block = tree.blockOf(item)! as ItemBlock;
      final id = next();
      return (
        replaced: {
          item: [
            ItemDraft.of(block, [
              TextDraft(id, text, level: level, from: joined),
              ...following,
              ...block.children.map(KeptDraft.new),
            ]),
          ],
        },
        gaps: null,
        tails: const {},
        slot: LeafSlot(id),
      );
    case GapSlot(:final gap):
      final id = next();
      return (
        replaced: _inserted(note, note.gapOf(gap)!, [
          TextDraft(id, text, level: level, from: joined),
          ...following,
        ], fresh),
        gaps: [
          for (final other in note.gaps)
            if (other.id != gap) other,
        ],
        tails: const {},
        slot: LeafSlot(id),
      );
  }
}

/// The blocks that put [drafts] where [gap] shows: in its container
/// after its block; in a list, between the two lists it splits the list
/// into, the second one taking an id from [fresh] and going on counting.
Map<BlockId, List<Draft>> _inserted(
  ShownNote note,
  Gap gap,
  List<Draft> drafts,
  Iterator<BlockId> fresh,
) {
  final container = note.tree.blockOf(gap.container)! as ContainerBlock;
  final children = [for (final child in container.children) KeptDraft(child)];
  final at = switch (gap.after) {
    null => 0,
    final after => children.indexWhere((child) => child.id == after) + 1,
  };
  final before = children.take(at).toList();
  final after = children.skip(at).toList();
  return {
    container.id: switch (container) {
      final ListBlock list => [
        if (before.isNotEmpty) ListDraft.of(list, before),
        ...drafts,
        if (after.isNotEmpty)
          ListDraft(
            (fresh..moveNext()).current,
            after,
            kind: list.kind,
            loose: list.loose,
            numbering: list.numbering,
            start: switch (list.numbering) {
              Numbering.sequential =>
                (list.items.first.marker.number ?? 1) + at,
              Numbering.same => list.items.first.marker.number ?? 1,
            },
          ),
      ],
      RootBlock() => [...before, ...drafts, ...after],
      final QuoteBlock quote => [
        QuoteDraft.of(quote, [...before, ...drafts, ...after]),
      ],
      final ItemBlock item => [
        ItemDraft.of(item, [...before, ...drafts, ...after]),
      ],
    },
  };
}
