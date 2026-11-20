import 'package:collection/collection.dart';

import '../editor_contract.dart';
import 'typing.dart';
import 'undoable_edit.dart';

/// One undo or redo step of the type's own ([S]), and its [id].
typedef HistoryStep<S> = ({int id, S step});

/// The undo and redo steps of one editing session, an immutable value:
/// each operation gives the history after it. Any file type: [S] is an
/// edit as its editor keeps it, to take back and make again.
final class EditHistory<S extends UndoableEdit<S>> {
  const EditHistory({
    this.undos = const [],
    this.redos = const [],
    this.run,
    this.start = HistoryStart.opened,
    this.nextId = 0,
  });

  /// The most steps kept; the oldest go first.
  static const limit = 100;

  /// The edits undo takes back, the latest last.
  final List<HistoryStep<S>> undos;

  /// The edits redo makes again, the next last.
  final List<HistoryStep<S>> redos;

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

  /// The history with [step], typing [typing], joined to the latest
  /// step, where its run takes it; `null` where it is a new step.
  EditHistory<S>? continued(S step, Typing? typing) =>
      switch ((run, undos.lastOrNull)) {
        (final run?, (:final id, step: final latest)?)
            when typing != null && run.takes(typing) =>
          _with(
            undos: [
              ...undos.take(undos.length - 1),
              (id: id, step: latest.joined(step)),
            ],
            run: run.then(typing),
          ),
        _ => null,
      };

  /// The history with [step], typing [typing] if it was typing, as a new
  /// step. Redo steps go.
  EditHistory<S> recorded(S step, Typing? typing) {
    final undos = [...this.undos, (id: nextId, step: step)];
    final dropped = undos.length > limit;
    return _with(
      undos: dropped ? undos.sublist(undos.length - limit) : undos,
      redos: const [],
      run: typing == null ? null : TypingRun(typing),
      start: dropped ? HistoryStart.limit : start,
      nextId: nextId + 1,
    );
  }

  /// The latest undo step, and the history once undo took it back (redo
  /// makes it again next); `null` if there is none.
  ({EditHistory<S> history, S step})? undone() => switch (undos.lastOrNull) {
    final latest? => (
      history: _with(
        undos: undos.sublist(0, undos.length - 1),
        redos: [...redos, latest],
      ),
      step: latest.step,
    ),
    null => null,
  };

  /// The next redo step, and the history once redo made it again (undo
  /// takes it back next); `null` if there is none.
  ({EditHistory<S> history, S step})? redone() => switch (redos.lastOrNull) {
    final next? => (
      history: _with(
        undos: [...undos, next],
        redos: redos.sublist(0, redos.length - 1),
      ),
      step: next.step,
    ),
    null => null,
  };

  /// The history with its typing run ended: the next typing is a step of
  /// its own.
  EditHistory<S> runEnded() => run == null ? this : _with();

  /// No steps: the file was replaced for the reason [start].
  EditHistory<S> cleared(HistoryStart start) =>
      EditHistory(start: start, nextId: nextId);

  /// This history with what is given changed; the typing run ends unless
  /// one is given.
  EditHistory<S> _with({
    List<HistoryStep<S>>? undos,
    List<HistoryStep<S>>? redos,
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
