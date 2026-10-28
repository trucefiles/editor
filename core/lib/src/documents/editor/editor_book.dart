import '../version.dart';
import 'editor_contract.dart';
import 'history/edit_history.dart';
import 'save_clock.dart';

/// The bookkeeping every editor keeps of its edits, whatever the document
/// type: their revs on the way to the file owner, the save timing, and the
/// undo history of snapshots of the type's own ([S]). An immutable value.
final class EditorBook<S> {
  EditorBook({
    required this.lineage,
    this.rev = 0,
    this.sentRev = 0,
    this.picks = 0,
    this.clock = const SaveClock(),
    EditHistory<S>? history,
  }) : history = history ?? EditHistory<S>();

  /// The file version the text descends from; `null` for a new document.
  /// Moves only with a change elsewhere or a pick taken.
  final Version? lineage;

  /// Counts the text changes, going on from a pick's.
  final int rev;

  /// The rev of the text last sent to the file owner.
  final int sentRev;

  /// Counts the picks taken.
  final int picks;

  final SaveClock clock;

  /// The undo and redo steps of this editing session.
  final EditHistory<S> history;

  /// What the state tells of the edits.
  EditorStatus get status => EditorStatus(
    unsent: sentRev != rev,
    canUndo: history.canUndo,
    canRedo: history.canRedo,
  );

  EditorBook<S> copyWith({
    Object? lineage = _same,
    int? rev,
    int? sentRev,
    int? picks,
    SaveClock? clock,
    EditHistory<S>? history,
  }) => EditorBook(
    lineage: identical(lineage, _same) ? this.lineage : lineage as Version?,
    rev: rev ?? this.rev,
    sentRev: sentRev ?? this.sentRev,
    picks: picks ?? this.picks,
    clock: clock ?? this.clock,
    history: history ?? this.history,
  );
}

/// Marks an [EditorBook.copyWith] field left as it is.
const _same = Object();
