/// What a command makes of a document, and where the caret goes when the
/// text it was in goes.
library;

import 'package:collection/collection.dart';

import '../doc/doc_nodes.dart';
import '../doc/doc_tree.dart';
import '../doc/normalized.dart';
import '../view/rows.dart';
import 'selection.dart';

/// A document tree after a command, and the selection after it; `null`
/// for a caret at the end of the document's last text.
typedef Change = ({DocTree doc, Selection? selection});

/// A document tree as Visual edit shows it, and the selection in it.
typedef Edited = ({DocTree doc, Selection selection});

/// [change] as it shows: its tree normalized (see `normalized`), its
/// selection resolved.
Edited settled(Change change) {
  final doc = normalized(change.doc, change.doc.freshIds);
  return (doc: doc, selection: change.selection ?? endOf(ViewRows(doc)));
}

/// A caret at the start of the first text [view] shows; where a block
/// without text shows first, that block selected.
Selection startOf(ViewRows view) => switch (view.rows.first) {
  TextRow(:final leaf) => TextSelection.caret(Place(leaf.id, 0)),
  BlockRow(:final leaf) => BlockSelection(leaf.id),
};

/// A caret at the end of the last text [view] shows; where none shows
/// after its last block without text (an HTML block that takes in the
/// rest), that block selected.
Selection endOf(ViewRows view) =>
    switch ((view.rows.whereType<TextRow>().lastOrNull, view.rows.lastOrNull)) {
      (_, final BlockRow last) => BlockSelection(last.leaf.id),
      (TextRow(:final leaf), _) => TextSelection.caret(
        Place(leaf.id, textOf(leaf).length),
      ),
      _ => throw StateError('a document shows a row'),
    };

/// Where the caret goes once the rows that [gone] says go are gone: at
/// the start of the next text after the first of them, else at the end
/// of the text above; the other way round if [above]; `null` (the end)
/// if neither stays.
Selection? caretPast(
  ViewRows view,
  bool Function(Row row) gone, {
  bool above = false,
}) {
  bool stays(Row row) => row is TextRow && !gone(row);
  final first = view.rows.indexWhere(gone);
  final next = caretAfter(view, gone);
  final previous = switch (view.rows.take(first).lastWhereOrNull(stays)) {
    TextRow(:final leaf) => TextSelection.caret(
      Place(leaf.id, textOf(leaf).length),
    ),
    _ => null,
  };
  return above ? previous ?? next : next ?? previous;
}

/// A caret at the start of the first text after the first row [past]
/// says, that [past] doesn't say too; `null` if there is none.
TextSelection? caretAfter(ViewRows view, bool Function(Row row) past) =>
    switch (view.rows
        .skip(view.rows.indexWhere(past))
        .firstWhereOrNull((row) => row is TextRow && !past(row))) {
      TextRow(:final leaf) => TextSelection.caret(Place(leaf.id, 0)),
      _ => null,
    };

/// Where the caret goes once the nodes [gone] go (see [caretPast]).
Selection? caretOnceGone(
  ViewRows view,
  Set<NodeId> gone, {
  bool above = false,
}) => caretPast(view, (row) => goesWith(view.doc, row, gone), above: above);

/// [selection] once the nodes [gone] go: kept where all it is on stays,
/// else as [caretOnceGone].
Selection? selectionOnceGone(
  ViewRows view,
  Selection selection,
  Set<NodeId> gone,
) {
  final leaves = switch (selection) {
    TextSelection(:final base, :final extent) => [base.leaf, extent.leaf],
    BlockSelection(:final block) => [block],
  };
  return leaves.any(
        (leaf) => switch (view.row(leaf)) {
          null => true,
          final row => goesWith(view.doc, row, gone),
        },
      )
      ? caretOnceGone(view, gone)
      : selection;
}

/// Whether [row] of [doc] goes with the nodes [gone]: its leaf or a
/// container it is in does.
bool goesWith(DocTree doc, Row row, Set<NodeId> gone) =>
    gone.contains(row.leaf.id) ||
    doc.pathOf(row.leaf.id).any((container) => gone.contains(container.id));
