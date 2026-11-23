import 'package:truce_files/truce_files.dart';

import '../text/text_summary.dart';
import '../text_file_owner/text_file_contract.dart' show FolderGets;
import 'editor_contract.dart';
import 'history/edit_history.dart';
import 'history/undoable_edit.dart';
import 'save_clock.dart';

/// The bookkeeping every editor keeps of its edits, whatever the file
/// type: their revs on the way to the file owner, the save timing, and the
/// undo history of edits as the type keeps them ([S]). An immutable value.
final class EditorBook<S extends UndoableEdit<S>> {
  EditorBook({
    required this.lineage,
    required this.summary,
    this.rev = 0,
    this.sentRev = 0,
    this.picks = 0,
    this.inFolderUpTo = 0,
    this.clock = const SaveClock(),
    EditHistory<S>? history,
  }) : history = history ?? EditHistory<S>();

  /// The file version the text descends from; `null` for a new file.
  /// Moves only with a change elsewhere or a pick taken.
  final Version? lineage;

  /// What lists show of the text as the file owner has it (see
  /// [EditorStatus.summary]).
  final TextSummary<Object?> summary;

  /// Counts the text changes, going on from a pick's.
  final int rev;

  /// The rev of the text last sent to the file owner.
  final int sentRev;

  /// Counts the picks taken.
  final int picks;

  /// The last rev the folder may hold: none after it ever went there
  /// (see [FolderGets]). At the start, the folder holds no edit.
  final int inFolderUpTo;

  /// Whether the edit made at [rev] may have reached the folder, so
  /// another device may hold it.
  bool mayBeInFolder(int rev) => rev <= inFolderUpTo;

  final SaveClock clock;

  /// The undo and redo steps of this editing session.
  final EditHistory<S> history;

  /// What the state tells of the edits.
  EditorStatus get status => EditorStatus(
    summary: summary,
    unsent: sentRev != rev,
    canUndo: history.canUndo,
    canRedo: history.canRedo,
  );

  EditorBook<S> copyWith({
    Object? lineage = _same,
    TextSummary<Object?>? summary,
    int? rev,
    int? sentRev,
    int? picks,
    int? inFolderUpTo,
    SaveClock? clock,
    EditHistory<S>? history,
  }) => EditorBook(
    lineage: identical(lineage, _same) ? this.lineage : lineage as Version?,
    summary: summary ?? this.summary,
    rev: rev ?? this.rev,
    sentRev: sentRev ?? this.sentRev,
    picks: picks ?? this.picks,
    inFolderUpTo: inFolderUpTo ?? this.inFolderUpTo,
    clock: clock ?? this.clock,
    history: history ?? this.history,
  );
}

/// Marks an [EditorBook.copyWith] field left as it is.
const _same = Object();
