import '../../common/moment.dart';
import '../../owners/owner.dart';
import '../version.dart';
import 'file_contract.dart';
import 'file_state.dart';
import 'file_work.dart';

/// How long the file owner waits.
final class FileTiming {
  const FileTiming({
    this.keep = const Duration(seconds: 2),
    this.publish = const Duration(minutes: 1),
  });

  /// After the last edit: the edits are kept on the device.
  final Duration keep;

  /// After edits were first kept on the device: they are written into the
  /// file (a new document waits for the user to leave it).
  final Duration publish;
}

/// The file owner's decision on [input] in [state].
Step<FileState, FileOutput> fileStep(
  FileState state,
  FileInput input,
  FileTiming timing,
) {
  final step = _Step(state, timing)..handle(input);
  return (state: step.state, outputs: step.outputs);
}

/// One input's handling: the state as it changes and what it leads to.
final class _Step {
  _Step(this.state, this.timing);

  FileState state;
  final FileTiming timing;
  final outputs = <FileOutput>[];

  FileWork get work => state.work;
  FileStatus get status => state.status;

  bool get _done => status is KeptAsConflict || status is Closed;

  void handle(FileInput input) => switch (input) {
    Edited() => _edited(input),
    SaveNow() => _save(),
    Secure(:final reason) => _secure(reason),
    Observed(:final observation, :final startedAt) => _observed(
      observation,
      startedAt,
    ),
    Pick() => _pick(input),
    RestoreMine() => _restore(),
    Discard() => _discard(),
    Moved(:final copy) => _moved(copy),
    TimerFired(:final id) => _timerFired(id),
    DraftKept(:final id, :final kept) => _draftKept(id, kept: kept),
    Wrote(:final id, :final outcome, :final endedAt) => _wrote(
      id,
      outcome,
      endedAt,
    ),
    BackedUp(:final id, :final ok) => _backedUp(id, ok: ok),
    ConflictKept(:final id, :final ok) => _conflictKept(id, ok: ok),
  };

  // Edits.

  void _edited(Edited edited) {
    if (_done) return;
    final sent = work.sent;
    if (sent != null && edited.lineage != sent.version) {
      // Made on a version the editor did not take: the user picks.
      _set(
        text: edited.text,
        rev: edited.rev,
        status: switch (status) {
          final ChangedElsewhere changed => changed,
          _ => ChangedElsewhere(sent),
        },
      );
      return _restartKeep();
    }
    if (edited.text == state.text) return _set(rev: edited.rev);
    _set(text: edited.text, rev: edited.rev);
    switch (status) {
      case ChangedElsewhere() || DeletedElsewhere():
        _restartKeep();
      case _ when work.expected == null && edited.text.trim().isEmpty:
        _settle(const Unwritten());
      case _:
        _set(status: const Editing(EditPhase.typing));
        _restartKeep();
    }
  }

  void _restartKeep() {
    final id = _id();
    _work(work.copyWith(keepTimer: id));
    outputs.add(StartTimer(id, timing.keep));
  }

  void _timerFired(EffectId id) {
    if (id == work.keepTimer) {
      _work(work.copyWith(keepTimer: null));
      _keepIfEdited();
    } else if (id == work.publishTimer) {
      _work(work.copyWith(publishTimer: null));
      _save();
    }
  }

  // Drafts.

  /// Keeps the edits on the device unless the draft holds them; drops it
  /// once the text is back to the file's while the user has to pick.
  void _keepIfEdited() {
    switch (status) {
      case ChangedElsewhere() || DeletedElsewhere()
          when state.text == work.expected?.text:
        _dropDraft();
      case Editing() || ChangedElsewhere() || DeletedElsewhere() || SaveFailed()
          when work.draft?.rev != state.rev:
        _keepDraft();
      case _:
        break;
    }
  }

  void _keepDraft() {
    final id = _id();
    _work(work.copyWith(draft: (id: id, rev: state.rev)));
    outputs.add(KeepDraft(id, base: work.expected?.text, text: state.text));
  }

  void _draftKept(EffectId id, {required bool kept}) {
    final draft = work.draft;
    if (draft?.id != id) return;
    if (!kept) {
      _work(work.copyWith(draft: null));
      if (work.securing case final securing?) {
        _work(
          work.copyWith(
            securing: (
              reason: securing.reason,
              tried: securing.tried,
              deviceRefused: true,
            ),
          ),
        );
        return _continueSecure();
      }
      // The device cannot keep them: into the file now.
      if (work.expected != null) _save();
      return;
    }
    _work(work.copyWith(keptRev: draft!.rev));
    _waitOnDevice();
    if (work.securing != null) _continueSecure();
  }

  /// The draft is kept: edits it holds wait on the device to be written.
  void _waitOnDevice() {
    if (status case Editing(phase: EditPhase.typing)
        when work.keptRev == state.rev) {
      _set(status: const Editing(EditPhase.onDevice));
    }
    if (status is Editing &&
        work.expected != null &&
        work.publishTimer == null) {
      final timer = _id();
      _work(work.copyWith(publishTimer: timer));
      outputs.add(StartTimer(timer, timing.publish));
    }
  }

  void _dropDraft() {
    if (work.keptRev == null && work.draft == null) return;
    _work(work.copyWith(draft: null, keptRev: null));
    outputs.add(const DropDraft());
  }

  /// No edits are pending any more: in the file, in a conflict copy, or
  /// dropped.
  void _settle(FileStatus settled) {
    _work(work.copyWith(keepTimer: null, publishTimer: null));
    _dropDraft();
    _set(status: settled);
  }

  // Writes.

  void _save() {
    if (status is! Editing && status is! SaveFailed) return;
    if (work.writing != null) return _work(work.copyWith(wanted: true));
    final id = _id();
    final expected = work.expected;
    final kind = expected == null ? WriteKind.create : WriteKind.write;
    final backUp = expected != null && expected.text != work.backedUp;
    _work(
      work.copyWith(
        wanted: false,
        writing: (id: id, text: state.text, kind: kind, before: status),
        backedUp: backUp ? expected.text : work.backedUp,
      ),
    );
    _set(status: const Editing(EditPhase.writing));
    outputs.add(switch (expected) {
      null => Create(id, state.text),
      final over => Write(id, state.text, over: over, backUpFirst: backUp),
    });
  }

  void _wrote(EffectId id, WriteOutcome outcome, Moment endedAt) {
    final writing = work.writing;
    if (writing == null || writing.id != id) return;
    final retried = work.retried;
    _work(work.copyWith(writing: null, lastWriteEnd: endedAt, retried: false));
    switch (outcome) {
      case Written(:final seen):
        _work(work.copyWith(expected: seen, backedUp: writing.text));
        if (writing.text == state.text) {
          _settle(const InStep());
        } else if (status is! Editing) {
          // Restored with edits made meanwhile: those go in too.
          _set(status: const Editing(EditPhase.typing));
          _work(work.copyWith(wanted: true));
        }
      case Changed(:final theirs)
          when !retried && theirs.text == work.expected?.text:
        // Only restamped: write again over the new stamp.
        _work(work.copyWith(expected: theirs, retried: true, wanted: true));
      case Changed(:final theirs) when theirs.text == state.text:
        _inStep(theirs);
      case Changed(:final theirs):
        _set(status: ChangedElsewhere(theirs));
      case Taken(:final there):
        _cameBack(there);
      case WriteGone():
        _goneElsewhere();
      case WriteFailed():
        _set(status: const SaveFailed());
    }
    if (work.securing != null) return _continueSecure();
    if (work.wanted) _save();
  }

  void _restore() {
    if (status is! DeletedElsewhere || work.writing != null) return;
    final id = _id();
    _work(
      work.copyWith(
        writing: (
          id: id,
          text: state.text,
          kind: WriteKind.restore,
          before: status,
        ),
      ),
    );
    outputs.add(Restore(id, state.text));
  }

  // Changes elsewhere.

  void _observed(Observation observation, Moment startedAt) {
    if (_done || work.writing != null || work.expected == null) return;
    // A scan that started before our last write ended may hold the old
    // version.
    if (work.lastWriteEnd case final end? when startedAt.isBefore(end)) {
      return;
    }
    switch (observation) {
      case Unknown():
        break;
      case Gone():
        _goneElsewhere();
      case Found(:final seen):
        _found(seen);
    }
  }

  void _found(Seen latest) {
    final expected = work.expected!;
    switch (status) {
      case DeletedElsewhere():
        _cameBack(latest);
      case _ when latest.version == expected.version:
        break;
      case _ when latest.text == expected.text:
        // Only restamped (some file systems report new times a moment
        // after a write).
        _work(work.copyWith(expected: latest));
      case _ when latest.text == state.text:
        _inStep(latest);
      case InStep():
        _replaced(latest);
      case _:
        _set(status: ChangedElsewhere(latest));
    }
  }

  /// The file is back after it looked deleted.
  void _cameBack(Seen latest) {
    final expected = work.expected!;
    if (latest.text == state.text) {
      _inStep(latest);
    } else if (state.text == expected.text) {
      _settle(const InStep());
      _replaced(latest);
    } else if (latest.version == expected.version) {
      _set(status: const Editing(EditPhase.typing));
      if (work.keptRev == state.rev) {
        _waitOnDevice();
      } else {
        _restartKeep();
      }
    } else {
      _set(status: ChangedElsewhere(latest));
    }
  }

  /// The editor shows [latest], unless it has edits not seen here.
  void _replaced(Seen latest) {
    _work(work.copyWith(expected: latest, sent: latest));
    _set(text: latest.text, status: const InStep());
    outputs.add(
      Replaced(latest.text, version: latest.version, ackRev: state.rev),
    );
  }

  void _inStep(Seen latest) {
    _work(work.copyWith(expected: latest));
    _settle(const InStep());
  }

  void _goneElsewhere() {
    _work(work.copyWith(publishTimer: null));
    if (status is! DeletedElsewhere) _set(status: const DeletedElsewhere());
  }

  void _moved(Seen copy) {
    if (work.expected != null) _work(work.copyWith(expected: copy));
  }

  // Picks.

  void _pick(Pick pick) {
    if (status case ChangedElsewhere(:final theirs)
        when theirs.version == pick.seen &&
            pick.rev == state.rev &&
            work.pick == null) {
      final id = _id();
      _work(work.copyWith(pick: (id: id, choice: pick.choice, theirs: theirs)));
      outputs.add(BackUpBoth(id, theirs: theirs, mine: state.text));
    }
  }

  void _backedUp(EffectId id, {required bool ok}) {
    final pick = work.pick;
    if (pick == null || pick.id != id) return;
    _work(work.copyWith(pick: null));
    final theirs = pick.theirs;
    if (!ok) {
      outputs.add(const PickNotKept());
    } else if (status case ChangedElsewhere(theirs: Seen(:final version))
        when version == theirs.version) {
      _work(
        work.copyWith(expected: theirs, sent: theirs, backedUp: theirs.text),
      );
      switch (pick.choice) {
        case PickChoice.mine:
          outputs.add(Picked(state.text, version: theirs.version));
          _set(status: const Editing(EditPhase.typing));
          _save();
        case PickChoice.theirs:
          _set(text: theirs.text);
          outputs.add(Picked(theirs.text, version: theirs.version));
          _settle(const InStep());
      }
    }
    if (work.securing != null) _continueSecure();
  }

  void _discard() {
    if (_done) return;
    final expected = work.expected;
    _work(work.copyWith(sent: expected));
    _set(text: expected?.text ?? '');
    outputs.add(Picked(state.text, version: expected?.version));
    _settle(expected == null ? const Unwritten() : const InStep());
  }

  // Securing.

  void _secure(SecureReason reason) {
    _work(
      work.copyWith(
        securing: (reason: reason, tried: false, deviceRefused: false),
      ),
    );
    _continueSecure();
  }

  /// Takes the next step to keep the edits somewhere lasting, once no
  /// write or pick is in flight.
  void _continueSecure() {
    final securing = work.securing!;
    if (work.writing != null || work.pick != null) return;
    switch (status) {
      case Unwritten() || InStep() || KeptAsConflict() || Closed():
        _answer(kept: true);
      case Editing():
        _tryWrite(securing);
      case SaveFailed() when !securing.tried:
        _tryWrite(securing);
      case DeletedElsewhere() when state.text == work.expected?.text:
        _settle(const DeletedElsewhere());
        _answer(kept: true);
      case ChangedElsewhere() || DeletedElsewhere() || SaveFailed()
          when securing.reason != SecureReason.close && !securing.deviceRefused:
        _keepOnDevice();
      case SaveFailed() when work.expected == null:
        // A new document has no file to keep a copy next to.
        if (!securing.deviceRefused) _keepDraft();
        _answer(kept: false);
      case ChangedElsewhere() || DeletedElsewhere() || SaveFailed():
        _keepAsConflict();
    }
  }

  void _tryWrite(Securing securing) {
    _work(
      work.copyWith(
        securing: (
          reason: securing.reason,
          tried: true,
          deviceRefused: securing.deviceRefused,
        ),
      ),
    );
    _save();
  }

  /// Hidden or left, not closed: the edits wait on the device for the
  /// user to pick or write them, and editing goes on.
  void _keepOnDevice() {
    if (work.keptRev == state.rev) return _answer(kept: true);
    if (work.draft?.rev != state.rev) _keepDraft();
  }

  void _keepAsConflict() {
    final id = _id();
    _work(
      work.copyWith(
        writing: (
          id: id,
          text: state.text,
          kind: WriteKind.conflict,
          before: status,
        ),
      ),
    );
    // Set before the copy is written, so no edit can slip past it.
    _set(status: const KeptAsConflict());
    outputs.add(KeepAsConflict(id, state.text));
  }

  void _conflictKept(EffectId id, {required bool ok}) {
    final writing = work.writing;
    if (writing == null || writing.id != id) return;
    _work(work.copyWith(writing: null));
    if (ok) {
      _settle(const KeptAsConflict());
    } else {
      // Kept on the device at least: the next start tries again.
      _set(status: writing.before);
      _keepDraft();
    }
    if (work.securing != null) _answer(kept: ok);
  }

  void _answer({required bool kept}) {
    final reason = work.securing!.reason;
    _work(work.copyWith(securing: null));
    outputs.add(Answer(reason, kept: kept));
    if (reason == SecureReason.close && kept) _set(status: const Closed());
  }

  // State.

  EffectId _id() {
    final id = EffectId(work.nextId);
    _work(work.copyWith(nextId: work.nextId + 1));
    return id;
  }

  void _work(FileWork work) => state = state.copyWith(work: work);

  void _set({FileStatus? status, String? text, int? rev}) =>
      state = state.copyWith(status: status, text: text, rev: rev);
}
