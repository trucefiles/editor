import 'package:collection/collection.dart';

import '../editor_contract.dart';
import 'snapshot.dart';
import 'typing.dart';

/// One undo or redo step: the document to come back to, and the step's
/// [id].
typedef HistoryStep = ({int id, Snapshot snapshot});

/// The undo and redo steps of one editing session, an immutable value:
/// each operation gives the history after it.
final class EditHistory {
  const EditHistory({
    this.undos = const [],
    this.redos = const [],
    this.run,
    this.start = HistoryStart.opened,
    this.nextId = 0,
  });

  /// The most steps kept; the oldest go first.
  static const limit = 100;

  /// What undo comes back to, the latest last.
  final List<HistoryStep> undos;

  /// What redo comes back to, the next last.
  final List<HistoryStep> redos;

  /// The typing the latest undo step holds, while more may join it.
  final TypingRun? run;

  /// Why the history starts where it does.
  final HistoryStart start;

  /// The id the next step gets.
  final int nextId;

  bool get canUndo => undos.isNotEmpty;
  bool get canRedo => redos.isNotEmpty;

  /// The id of the step undo takes back next.
  int? get latestId => undos.lastOrNull?.id;

  /// The history with [typing] joined to the latest step, where its run
  /// takes it; `null` where it is a new step.
  EditHistory? continued(Typing? typing) => switch (run) {
    final run? when typing != null && run.takes(typing) => _with(
      run: run.then(typing),
    ),
    _ => null,
  };

  /// The history with an edit that changed the document from [before] as
  /// a new step, its typing [typing] if it was typing. Redo steps go.
  EditHistory recorded(Snapshot before, Typing? typing) {
    final undos = [...this.undos, (id: nextId, snapshot: before)];
    final dropped = undos.length > limit;
    return _with(
      undos: dropped ? undos.sublist(undos.length - limit) : undos,
      redos: const [],
      run: typing == null ? null : TypingRun(typing),
      start: dropped ? HistoryStart.limit : start,
      nextId: nextId + 1,
    );
  }

  /// The latest undo step's document, and the history once undo went
  /// back to it from [now]; `null` if there is none.
  ({EditHistory history, Snapshot back})? undone(Snapshot now) =>
      switch (undos.lastOrNull) {
        (:final id, :final snapshot)? => (
          history: _with(
            undos: undos.sublist(0, undos.length - 1),
            redos: [...redos, (id: id, snapshot: now)],
          ),
          back: snapshot,
        ),
        null => null,
      };

  /// The next redo step's document, and the history once redo went to
  /// it from [now]; `null` if there is none.
  ({EditHistory history, Snapshot back})? redone(Snapshot now) =>
      switch (redos.lastOrNull) {
        (:final id, :final snapshot)? => (
          history: _with(
            undos: [...undos, (id: id, snapshot: now)],
            redos: redos.sublist(0, redos.length - 1),
          ),
          back: snapshot,
        ),
        null => null,
      };

  /// The history with its typing run ended: the next typing is a step of
  /// its own.
  EditHistory runEnded() => run == null ? this : _with();

  /// No steps: the document was replaced for the reason [start].
  EditHistory cleared(HistoryStart start) =>
      EditHistory(start: start, nextId: nextId);

  /// This history with what is given changed; the typing run ends unless
  /// one is given.
  EditHistory _with({
    List<HistoryStep>? undos,
    List<HistoryStep>? redos,
    TypingRun? run,
    HistoryStart? start,
    int? nextId,
  }) => EditHistory(
    undos: undos ?? this.undos,
    redos: redos ?? this.redos,
    run: run,
    start: start ?? this.start,
    nextId: nextId ?? this.nextId,
  );
}
