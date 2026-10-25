import 'package:collection/collection.dart';

import '../../document_tree.dart';
import '../../tree/blocks.dart';
import '../../visible/visible_text.dart';
import '../../write/block/gaps.dart';
import 'rows.dart';
import 'selection.dart';
import 'slot.dart';

/// What Visual edit shows of a document: its tree, with the parts that are
/// in no file yet. Gaps are empty paragraphs; tails are what a text
/// place shows after its written text, which Markdown would drop at a
/// leaf's end (spaces, line breaks) until text follows. Immutable;
/// questions are lookups, derived once when first asked.
final class ShownDocument {
  ShownDocument(
    this.tree, {
    List<Gap> gaps = const [],
    Map<Slot, VisibleText> tails = const {},
    this.done,
    this.nextGap = GapId.first,
  }) : gaps = List.unmodifiable(gaps),
       tails = Map.unmodifiable(tails);

  final DocumentTree tree;

  /// The gaps made by edits, in the order they show.
  final List<Gap> gaps;

  /// What text places show after their written text; none is empty.
  final Map<Slot, VisibleText> tails;

  /// How checked items show; `null` in place.
  final DoneSections? done;

  /// The id the next new gap takes.
  final GapId nextGap;

  /// This document with its checked items shown as [done] says.
  ShownDocument withDone(DoneSections? done) => ShownDocument(
    tree,
    gaps: gaps,
    tails: tails,
    done: done,
    nextGap: nextGap,
  );

  /// Every gap that shows: [gaps], and where the last row would show no
  /// text to type a paragraph in (none, a block without text, or code)
  /// the [GapId.end] gap after the last block; none after an HTML block
  /// that takes in the rest of its container.
  late final List<Gap> shownGaps = () {
    final shown = gaps.where(_canShow).toList();
    final last = tree.root.children.lastOrNull;
    final takesRest = last is LeafBlock && takesInTheRest(last);
    final endsInText = switch (rowsOf(tree.root, shown, done).lastOrNull) {
      TextRow(slot: LeafSlot(:final leaf)) => tree.blockOf(leaf) is! CodeBlock,
      TextRow() => true,
      BlockRow() || null => false,
    };
    return [
      ...shown,
      if (!takesRest && !endsInText)
        Gap(GapId.end, container: tree.root.id, after: last?.id),
    ];
  }();

  /// Whether [gap] can show: no HTML block before it in its container
  /// takes it in.
  bool _canShow(Gap gap) => switch (tree.blockOf(gap.container)) {
    final ContainerBlock container =>
      !container.children
          .take(
            container.children.indexWhere((child) => child.id == gap.after) + 1,
          )
          .any((child) => child is LeafBlock && takesInTheRest(child)),
    _ => true,
  };

  /// The rows, in the order they show.
  late final List<Row> rows = rowsOf(tree.root, shownGaps, done);

  late final Map<Slot, int> _slotRows = {
    for (final (index, row) in rows.indexed)
      if (row case TextRow(:final slot)) slot: index,
  };

  late final Map<BlockId, int> _blockRows = {
    for (final (index, row) in rows.indexed)
      if (row case BlockRow(:final leaf)) leaf.id: index,
  };

  late final Map<GapId, Gap> _gaps = {for (final gap in shownGaps) gap.id: gap};

  /// The index of the row [slot] shows in; `null` if it shows in none.
  int? rowOf(Slot slot) => _slotRows[slot];

  /// The index of the row the block [id] without text shows in; `null`
  /// if it shows in none.
  int? blockRowOf(BlockId id) => _blockRows[id];

  /// The gap [id]; `null` if none shows.
  Gap? gapOf(GapId id) => _gaps[id];

  /// The text [slot]'s written content shows: a leaf's text or code; an
  /// item's own place and a gap have none.
  VisibleText writtenTextOf(Slot slot) => switch (slot) {
    LeafSlot(:final leaf) => switch (tree.blockOf(leaf)) {
      final TextLeaf text => visibleTextOf(text.text),
      final CodeBlock code => VisibleText([TextPiece(code.code)]),
      _ => VisibleText.empty,
    },
    ItemSlot() || GapSlot() => VisibleText.empty,
  };

  /// The text [slot] shows: its written text and its tail.
  VisibleText textOf(Slot slot) =>
      writtenTextOf(slot) + (tails[slot] ?? VisibleText.empty);

  /// Where the caret goes for the rows that [gone] says no longer show:
  /// at the start of the next text after the first of them, else at the
  /// end of the text above, else in the end gap; where none shows (after
  /// an HTML block that takes in the rest), that block is selected.
  Selection caretPast(bool Function(Row row) gone) {
    bool stays(Row row) =>
        row is TextRow && row.slot != const GapSlot(GapId.end) && !gone(row);
    final first = rows.indexWhere(gone);
    return switch ((
      rows.skip(first).firstWhereOrNull(stays),
      rows.take(first).lastWhereOrNull(stays),
      rows.whereType<BlockRow>().lastOrNull,
    )) {
      (TextRow(:final slot), _, _) => TextSelection.caret(Place(slot, 0)),
      (_, TextRow(:final slot), _) => TextSelection.caret(
        Place(slot, textOf(slot).length),
      ),
      (_, _, BlockRow(:final leaf))
          when rowOf(const GapSlot(GapId.end)) == null =>
        BlockSelection(leaf.id),
      _ => const TextSelection.caret(Place(GapSlot(GapId.end), 0)),
    };
  }
}
