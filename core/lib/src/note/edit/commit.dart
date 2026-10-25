import 'package:collection/collection.dart';

import '../note_tree.dart';
import '../tree/blocks.dart';
import '../visible/visible_text.dart';
import '../write/block/leaf_lines.dart';
import '../write/draft.dart';
import '../write/note_writer.dart';
import 'common_ends.dart';
import 'redraft.dart';
import 'settle/wrapping.dart';
import 'settle/writable_text.dart';
import 'shown/rows.dart';
import 'shown/selection.dart';
import 'shown/shown_note.dart';
import 'shown/slot.dart';

/// What a command changes in a shown note: blocks [replaced] by drafts
/// whose text is the text they show; the [gaps] if they change; the
/// [selection] after it, in the drafts' slots.
final class Edit {
  Edit({
    this.replaced = const {},
    this.gaps,
    this.nextGap,
    this.tails = const {},
    required this.selection,
    this.done,
  });

  final Map<BlockId, List<Draft>> replaced;
  final List<Gap>? gaps;

  /// The id the next new gap takes, if [gaps] took ids.
  final GapId? nextGap;

  /// What text places that write nothing now show.
  final Map<Slot, VisibleText> tails;
  final Selection selection;

  /// How checked items show after it, if that changes.
  final DoneSections? done;
}

/// A shown note and the selection in it.
typedef Edited = ({ShownNote note, Selection selection});

/// [note] with [edit] made: each changed text written as much as a leaf
/// can hold, its tail kept to show; an empty paragraph shown as a gap,
/// or as its item's own place where it starts one; gaps moved after the
/// block before them where theirs went; the drafts written.
Edited commit(ShownNote note, Edit edit) {
  final settle = _Settle(note, edit.nextGap ?? note.nextGap);
  final draft = redrafted(note.tree, edit.replaced);
  final settled = RootDraft(
    draft.root,
    settle.children(draft.children, container: draft.root.id, prefix: 0),
  );
  final tree = written(note.tree, settled);
  final gaps = _gapsAfter(
    note.tree,
    tree,
    edit.gaps ?? note.gaps,
    settle.newGaps,
  );
  final shown = ShownNote(
    tree,
    gaps: gaps,
    done: edit.done ?? note.done,
    nextGap: settle.nextGap,
  );
  Slot moved(Slot slot) => settle.moves[slot] ?? slot;
  final tails = {
    for (final MapEntry(key: slot, value: tail) in {
      ...note.tails,
      ...edit.tails,
      ...settle.tails,
    }.entries)
      if (!tail.isEmpty && !settle.moves.containsKey(slot)) slot: tail,
  };
  return (
    note: ShownNote(
      tree,
      gaps: gaps,
      tails: {
        for (final MapEntry(key: slot, value: tail) in tails.entries)
          if (shown.rowOf(slot) != null) slot: tail,
      },
      done: shown.done,
      nextGap: settle.nextGap,
    ),
    selection: switch (edit.selection) {
      TextSelection(:final base, :final extent) => TextSelection(
        Place(moved(base.slot), base.offset),
        Place(moved(extent.slot), extent.offset),
      ),
      final selection => selection,
    },
  );
}

/// One pass over a draft that makes its text writable.
final class _Settle {
  _Settle(this._note, this.nextGap);

  final ShownNote _note;
  GapId nextGap;

  /// The tails of the text places written anew, by their slot.
  final tails = <Slot, VisibleText>{};

  /// Where the text of emptied paragraphs shows now.
  final moves = <Slot, Slot>{};

  /// The gaps emptied paragraphs became, with the block they were.
  final newGaps = <(Gap, BlockId)>[];

  NoteTree get _tree => _note.tree;

  /// [drafts], children of [container] whose lines start after [prefix]
  /// columns of marks, settled.
  List<Draft> children(
    List<Draft> drafts, {
    required BlockId container,
    required int prefix,
    BlockId? item,
  }) {
    final settled = <Draft>[];
    for (final (index, draft) in drafts.indexed) {
      switch (draft) {
        case TextDraft():
          final (:text, :tail) = writableText(
            draft.text,
            shape: _shapeOf(draft, prefix),
            definitions: _tree.definitions,
          );
          if (text.isEmpty && draft.level == null) {
            final slot =
                item != null &&
                    settled.isEmpty &&
                    _startsNoText(drafts.skip(index + 1))
                ? ItemSlot(item)
                : _gap(container, after: settled.lastOrNull?.id, was: draft.id);
            moves[LeafSlot(draft.id)] = slot;
            tails[slot] = tail;
          } else {
            settled.add(
              TextDraft(draft.id, text, level: draft.level, from: draft.from),
            );
            tails[LeafSlot(draft.id)] = tail;
          }
        case QuoteDraft(:final id, :final children, :final from):
          settled.add(
            QuoteDraft(
              id,
              this.children(children, container: id, prefix: prefix + 2),
              from: from,
            ),
          );
        case ListDraft(:final items):
          settled.add(_list(draft, items, prefix));
        case ItemDraft() || KeptDraft() || CodeDraft():
          settled.add(draft);
      }
    }
    return settled;
  }

  ListDraft _list(ListDraft list, List<Draft> items, int prefix) => ListDraft(
    list.id,
    [
      for (final item in items)
        switch (item) {
          ItemDraft(:final id, :final children, :final checked, :final from) =>
            ItemDraft(
              id,
              this.children(
                children,
                container: id,
                item: id,
                prefix: prefix + _itemWidth(item, list),
              ),
              checked: checked,
              from: from,
            ),
          _ => item,
        },
    ],
    kind: list.kind,
    loose: list.loose,
    numbering: list.numbering,
    start: list.start,
    from: list.from,
  );

  Slot _gap(
    BlockId container, {
    required BlockId? after,
    required BlockId was,
  }) {
    final gap = Gap(nextGap, container: container, after: after);
    nextGap = nextGap.next;
    newGaps.add((gap, was));
    return GapSlot(gap.id);
  }

  TextShape _shapeOf(TextDraft draft, int prefix) {
    if (draft.level != null) {
      return HeadingShape(setext: keepsSetext(draft.level, draft.from));
    }
    final old = draft.from
        .map((leaf) => visibleTextOf(leaf.text))
        .fold(VisibleText.empty, (all, text) => all + text);
    final (:head, :tail) = commonEnds(old.text, draft.text.text);
    return ParagraphShape(
      edited: (start: head, end: draft.text.length - tail),
      width: wrapWidthOf([
        for (final line
            in draft.from.firstOrNull?.lines ?? const <SourceLine>[])
          line.text,
      ]),
      prefix: prefix,
    );
  }
}

/// Whether blocks [rest] after an item's emptied first paragraph leave
/// it without text at its start.
bool _startsNoText(Iterable<Draft> rest) => switch (rest.firstOrNull) {
  null || ListDraft() || KeptDraft(block: ListBlock()) => true,
  _ => false,
};

/// The columns an item's marks take: as before for an old item, else
/// as its marker would.
int _itemWidth(ItemDraft item, ListDraft list) =>
    item.from?.contentColumn ??
    (list.kind == ListKind.numbered ? 3 : 2) + (item.checked == null ? 0 : 4);

/// [gaps] of [before] as they show in [after], with [added] gaps that
/// emptied paragraphs became, each where its paragraph was (gaps after
/// the paragraph then follow it; a new paragraph was right after the
/// block before it): a gap whose block went shows after the nearest
/// block before it that stayed; one whose container went is gone.
List<Gap> _gapsAfter(
  NoteTree before,
  NoteTree after,
  List<Gap> gaps,
  List<(Gap, BlockId)> added,
) {
  final withAdded = added.fold(gaps, (gaps, entry) {
    final (gap, was) = entry;
    bool at(Gap other, BlockId? block) =>
        other.container == gap.container && other.after == block;
    final following = gaps.indexWhere((other) => at(other, was));
    final peers = before.blockOf(was) == null
        ? gaps.indexWhere((other) => at(other, gap.after))
        : gaps.lastIndexWhere((other) => at(other, gap.after)) + 1;
    final index = following >= 0
        ? following
        : peers >= 0
        ? peers
        : gaps.length;
    Gap moved(Gap other) =>
        at(other, was) ? other.movedAfter(gap.after) : other;
    return [
      ...gaps.take(index).map(moved),
      gap,
      ...gaps.skip(index).map(moved),
    ];
  });
  final addedIds = {for (final (gap, _) in added) gap.id};
  return [
    for (final gap in withAdded)
      ?(addedIds.contains(gap.id) ? gap : _anchored(gap, before, after)),
  ];
}

/// [gap] as it shows in [after]; `null` if its container went.
Gap? _anchored(Gap gap, NoteTree before, NoteTree after) {
  final container = after.blockOf(gap.container);
  if (container is! ContainerBlock) return null;
  final children = {for (final child in container.children) child.id};
  if (gap.after == null || children.contains(gap.after)) return gap;
  final old = before.blockOf(gap.container);
  final olds = old is ContainerBlock ? old.children : const <Block>[];
  final index = olds.indexWhere((child) => child.id == gap.after);
  return gap.movedAfter(
    olds
        .take(index < 0 ? 0 : index)
        .lastWhereOrNull((child) => children.contains(child.id))
        ?.id,
  );
}
