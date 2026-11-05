/// Where a command acted, as the rows that show it before and after.
library;

import 'package:collection/collection.dart';

import '../../doc/doc_nodes.dart';
import '../../view/rows.dart';
import '../change.dart';
import 'command.dart';

/// Where an input's commands acted: the leaf of the row the first acted
/// at before it, and of the row the last shows at after it.
typedef ActedAt = ({NodeId? before, NodeId? after});

/// The leaf of the row [command] acts at in [view]: the place, item,
/// block or selection it names; `null` only where it names none (no
/// checked item to clear or move, or "Clear checked" and "Move to end"
/// without their items named: see `withItemsNamed`).
NodeId? actedOn(ViewRows view, Command command) {
  NodeId firstOf(NodeId block) => leavesIn(view.doc.nodeOf(block)!).first.id;
  return switch (command) {
    Paste(:final selection) ||
    DeleteRange(:final selection) => selection.endLeaf,
    LineBreak(:final range) ||
    SplitBlock(:final range) ||
    ReplaceText(:final range) ||
    SetLink(:final range) ||
    Indent(selection: final range) ||
    Outdent(selection: final range) ||
    SetFrame(selection: final range) ||
    ToggleStyle(selection: final range) => range.endLeaf,
    InsertText(:final at) ||
    JoinWithPrevious(:final at) ||
    JoinWithNext(:final at) ||
    SetHeading(:final at) ||
    RemoveLink(:final at) ||
    RemoveBlockNextTo(caret: final at) => at.leaf,
    RemoveFrame(:final leaf) => leaf,
    RemoveSelectedBlock(:final block) ||
    LineAfter(:final block) ||
    LineInPlace(:final block) ||
    AddDivider(after: final block) ||
    CloseRaw(:final block) => block,
    Toggle(:final item) ||
    DeleteItem(:final item) ||
    MoveItem(:final item) => firstOf(item),
    AddItem(:final list) => leavesIn(view.doc.nodeOf(list)!).last.id,
    ClearChecked(:final items) ||
    MoveToEnd(:final items) => switch (items?.firstOrNull) {
      final item? => firstOf(item),
      null => null,
    },
  };
}

/// The leaf of the row that shows an edit after it, which acted on
/// [acted] in [before] and gave [edited]: the caret it leaves; else
/// [acted] where it stays; else the next row that stays (the previous one
/// at the end), as the caret goes when the delete button removes an item.
NodeId? shownAfter(ViewRows before, Edited edited, NodeId? acted) {
  bool gone(NodeId leaf) => edited.doc.nodeOf(leaf) == null;
  return switch ((edited.selection, acted)) {
    (final selection?, _) => selection.endLeaf,
    (null, null) => null,
    (null, final acted?) when !gone(acted) => acted,
    (null, _) => switch (caretPast(before, (row) => gone(row.leaf.id))) {
      CaretAt(:final selection) => selection.endLeaf,
      CaretAtEnd() || NoCaret() => null,
    },
  };
}
