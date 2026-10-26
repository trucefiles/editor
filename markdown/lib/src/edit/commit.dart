import 'dart:math';

import 'package:collection/collection.dart';

import '../document_tree.dart';
import '../read/document_reading.dart';
import '../tree/blocks.dart';
import '../visible/visible_text.dart';
import '../write/block/leaf_lines.dart';
import '../write/document_writer.dart';
import '../write/draft.dart';
import 'common_ends.dart';
import 'redraft.dart';
import 'settle/wrapping.dart';
import 'settle/writable_text.dart';
import 'shown/rows.dart';
import 'shown/selection.dart';
import 'shown/shown_document.dart';
import 'shown/slot.dart';

/// What a command changes in a shown document: blocks [replaced] by drafts
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

/// A shown document and the selection in it.
typedef Edited = ({ShownDocument document, Selection selection});

/// [document] with [edit] made: each changed text written as much as a leaf
/// can hold, its tail kept to show; an empty paragraph shown as a gap,
/// or as its item's own place where it starts one; gaps moved after the
/// block before them where theirs went; the drafts written.
Edited commit(ShownDocument document, Edit edit) {
  final draft = redrafted(document.tree, edit.replaced);
  final settle = _Settle(
    edit.nextGap ?? document.nextGap,
    definitions: definitionsByLabel(draft.children.expand(_definitionsIn)),
  );
  final settled = RootDraft(
    draft.root,
    settle.children(draft.children, container: draft.root.id, prefix: 0),
  );
  final tree = written(document.tree, settled);
  final gaps = _gapsAfter(
    document.tree,
    tree,
    edit.gaps ?? document.gaps,
    settle.newGaps,
  );
  final shown = ShownDocument(
    tree,
    gaps: gaps,
    done: edit.done ?? document.done,
    nextGap: settle.nextGap,
  );
  Slot moved(Slot slot) => settle.moves[slot] ?? slot;
  final tails = {
    for (final MapEntry(key: slot, value: tail) in {
      ...document.tails,
      ...edit.tails,
      ...settle.tails,
    }.entries)
      if (!tail.isEmpty && !settle.moves.containsKey(slot)) slot: tail,
  };
  final after = ShownDocument(
    tree,
    gaps: gaps,
    tails: {
      for (final MapEntry(key: slot, value: tail) in tails.entries)
        if (shown.rowOf(slot) != null) slot: tail,
    },
    done: shown.done,
    nextGap: settle.nextGap,
  );
  return (
    document: after,
    selection: switch (edit.selection) {
      TextSelection(:final base, :final extent) => _shownSelection(
        after,
        {
          for (final id in _textIds(settled.children))
            if (tree.blockOf(id) is HtmlBlock) id,
        },
        TextSelection(
          Place(moved(base.slot), base.offset),
          Place(moved(extent.slot), extent.offset),
        ),
      ),
      final selection => selection,
    },
  );
}

/// [selection] on what [document] shows: past the [raw] blocks, text
/// Markdown now reads as HTML blocks, where it is on one or on text one
/// took in; each place within its text, which the file may have held
/// shorter (code in an item); a place that no longer shows given up.
Selection _shownSelection(
  ShownDocument document,
  Set<BlockId> raw,
  TextSelection selection,
) {
  final places = [selection.base, selection.extent];
  if (raw.isNotEmpty &&
      places.any(
        (place) =>
            document.rowOf(place.slot) == null &&
            place.slot != const GapSlot(GapId.end),
      )) {
    return document.caretPast(
      (row) => row is BlockRow && raw.contains(row.leaf.id),
    );
  }
  Place? shown(Place place) => switch (document.rowOf(place.slot)) {
    null => null,
    _ => Place(
      place.slot,
      min(place.offset, document.textOf(place.slot).length),
    ),
  };
  // A gap the edit left may be gone with its container.
  return switch ((shown(selection.base), shown(selection.extent))) {
    (final base?, final extent?) => TextSelection(base, extent),
    (final place?, null) || (null, final place?) => TextSelection.caret(place),
    (null, null) => document.firstCaret,
  };
}

/// The ids of the text drafts in [drafts], at any depth.
Iterable<BlockId> _textIds(List<Draft> drafts) => drafts.expand(
  (draft) => switch (draft) {
    TextDraft(:final id) => [id],
    QuoteDraft(:final children) ||
    ItemDraft(:final children) => _textIds(children),
    ListDraft(:final items) => _textIds(items),
    _ => const <BlockId>[],
  },
);

/// The link definitions [draft] holds, in file order.
Iterable<LinkDefinition> _definitionsIn(Draft draft) => switch (draft) {
  KeptDraft(:final block) => definitionsIn(block),
  ListDraft(:final items) => items.expand(_definitionsIn),
  ItemDraft(:final children) ||
  QuoteDraft(:final children) => children.expand(_definitionsIn),
  TextDraft() || CodeDraft() => const [],
};

/// One pass over a draft that makes its text writable.
final class _Settle {
  _Settle(this.nextGap, {required this.definitions});

  /// The link definitions the document holds once the draft is written.
  final Map<String, LinkDefinition> definitions;

  GapId nextGap;

  /// The tails of the text places written anew, by their slot.
  final tails = <Slot, VisibleText>{};

  /// Where the text of emptied paragraphs shows now.
  final moves = <Slot, Slot>{};

  /// The gaps emptied paragraphs became, with the block they were.
  final newGaps = <(Gap, BlockId)>[];

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
            definitions: definitions,
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
  DocumentTree before,
  DocumentTree after,
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

/// [gap] as it shows in [after]; a gap whose container went goes with
/// the block it was after (before its container's first block if it
/// was first), `null` if that went too.
Gap? _anchored(Gap gap, DocumentTree before, DocumentTree after) {
  final container = after.blockOf(gap.container);
  if (container is! ContainerBlock) return _withNeighbor(gap, before, after);
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

/// [gap], whose container went, in the container its neighbor block is
/// in now; `null` if that went too.
Gap? _withNeighbor(Gap gap, DocumentTree before, DocumentTree after) {
  final old = before.blockOf(gap.container);
  final neighbor = switch (gap.after) {
    final id? => after.blockOf(id),
    null when old is ContainerBlock => switch (old.children.firstOrNull) {
      final first? => after.blockOf(first.id),
      null => null,
    },
    null => null,
  };
  final parent = neighbor == null ? null : after.parentOf(neighbor);
  if (neighbor == null || parent == null) return null;
  final siblings = parent.children;
  return Gap(
    gap.id,
    container: parent.id,
    after: gap.after == null
        ? siblings.take(siblings.indexOf(neighbor)).lastOrNull?.id
        : neighbor.id,
  );
}
