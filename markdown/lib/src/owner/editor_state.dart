import 'package:truce_core/truce_core.dart' show Version;

import '../edit/shown/selection.dart';
import '../edit/shown/shown_document.dart';
import '../lines/line.dart';
import '../tree/blocks.dart';
import '../visible/formatting.dart';
import 'editor_contract.dart';

/// What the editor shows and how: the editor owner's state.
final class EditorState {
  const EditorState({
    required this.document,
    required this.selection,
    required this.lineage,
    this.mode = EditMode.visual,
    this.checkedItems = CheckedItems.moveToEnd,
    this.rev = 0,
    this.revision = 0,
    this.typingStyle,
    this.raw,
    this.holds = const Holds(),
    this.undo,
    this.nextId = 0,
  });

  final ShownDocument document;

  /// The selection in Visual edit; Markdown edit keeps its own caret.
  final Selection selection;

  final EditMode mode;
  final CheckedItems checkedItems;

  /// Counts the text changes commands made.
  final int rev;

  /// The file version the text descends from; `null` for a new document.
  /// Moves only with a change elsewhere or a pick taken.
  final Version? lineage;

  /// Counts the changes to what shows; inputs name the one they saw.
  final int revision;

  /// What text typed at a caret gets, once the user set it there; `null`
  /// while it follows the text at the caret.
  final Formatting? typingStyle;

  /// The block shown as raw text, if one is.
  final RawRegion? raw;

  /// Toggled items whose move waits for the toggle to settle.
  final Holds holds;

  /// The undo of the last removal, while it can be made.
  final Removal? undo;

  final int nextId;

  EditorState copyWith({
    ShownDocument? document,
    Selection? selection,
    EditMode? mode,
    CheckedItems? checkedItems,
    int? rev,
    Object? lineage = _same,
    int? revision,
    Object? typingStyle = _same,
    Object? raw = _same,
    Holds? holds,
    Object? undo = _same,
    int? nextId,
  }) => EditorState(
    document: document ?? this.document,
    selection: selection ?? this.selection,
    mode: mode ?? this.mode,
    checkedItems: checkedItems ?? this.checkedItems,
    rev: rev ?? this.rev,
    lineage: identical(lineage, _same) ? this.lineage : lineage as Version?,
    revision: revision ?? this.revision,
    typingStyle: identical(typingStyle, _same)
        ? this.typingStyle
        : typingStyle as Formatting?,
    raw: identical(raw, _same) ? this.raw : raw as RawRegion?,
    holds: holds ?? this.holds,
    undo: identical(undo, _same) ? this.undo : undo as Removal?,
    nextId: nextId ?? this.nextId,
  );
}

/// Marks an [EditorState.copyWith] field left as it is.
const _same = Object();

/// A block shown as its raw lines, [first] to [last], with the caret
/// from [base] to [extent] in their text.
final class RawRegion {
  const RawRegion(
    this.first,
    this.last, {
    required this.base,
    required this.extent,
  });

  final LineId first;
  final LineId last;
  final int base;
  final int extent;
}

/// Toggled items waiting to settle, each with the box it had before;
/// [timer] the settle timer running, `null` once it fired.
final class Holds {
  const Holds({this.items = const {}, this.timer});

  final Map<BlockId, bool> items;
  final int? timer;

  bool get isEmpty => items.isEmpty;
}

/// How to undo removal [id]: the document before it, valid at [rev].
typedef Removal = ({
  int id,
  ShownDocument before,
  Selection selection,
  int rev,
});
