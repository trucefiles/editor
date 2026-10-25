import 'package:collection/collection.dart';

import '../../note_tree.dart';
import '../../tree/blocks.dart';
import '../../visible/visible_text.dart';
import 'rows.dart';
import 'slot.dart';

/// What Visual edit shows of a note: its tree, with the parts that are
/// in no file yet. Gaps are empty paragraphs; tails are what a text
/// place shows after its written text, which Markdown would drop at a
/// leaf's end (spaces, line breaks) until text follows. Immutable;
/// questions are lookups, derived once when first asked.
final class ShownNote {
  ShownNote(
    this.tree, {
    List<Gap> gaps = const [],
    Map<Slot, VisibleText> tails = const {},
    this.done,
    this.nextGap = GapId.first,
  }) : gaps = List.unmodifiable(gaps),
       tails = Map.unmodifiable(tails);

  final NoteTree tree;

  /// The gaps made by edits, in the order they show.
  final List<Gap> gaps;

  /// What text places show after their written text; none is empty.
  final Map<Slot, VisibleText> tails;

  /// How checked items show; `null` in place.
  final DoneSections? done;

  /// The id the next new gap takes.
  final GapId nextGap;

  /// Every gap that shows: [gaps], and after a last block without text
  /// (or in an empty note) the [GapId.end] gap.
  late final List<Gap> shownGaps = [...gaps, ?_endGap];

  Gap? get _endGap {
    final last = tree.root.children.lastOrNull;
    final hasText = last is TextLeaf || last is ContainerBlock;
    final gapAfter = gaps.any(
      (gap) => gap.container == tree.root.id && gap.after == last?.id,
    );
    return hasText || gapAfter
        ? null
        : Gap(GapId.end, container: tree.root.id, after: last?.id);
  }

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
}
