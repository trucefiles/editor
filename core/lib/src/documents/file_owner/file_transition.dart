import '../../common/moment.dart';
import '../../owners/owner.dart';
import '../version.dart';
import 'file_contract.dart';
import 'file_state.dart';
import 'file_work.dart';

/// The file owner's decision on [input] in [state], with its [work].
Step<FileState, FileWork, FileOutput> fileStep(
  FileState state,
  FileWork work,
  FileInput input,
) {
  final step = _Step(state, work)..handle(input);
  return (state: step.shown, work: step.work, outputs: step.outputs);
}

/// One input's handling: the state as it changes and what it leads to.
/// Inputs update what is known and asked; [_next] then starts the next
/// I/O once none is under way.
final class _Step {
  _Step(this.state, this.work);

  FileState state;
  FileWork work;
  final outputs = <FileOutput>[];
  FileStatus get status => state.status;

  bool get _done => status is KeptAsConflict || status is Closed;

  /// Whether there are edits the file does not hold.
  bool get _hasEdits => switch (status) {
    Editing() || SaveFailed() => true,
    ChangedElsewhere() ||
    DeletedElsewhere() => state.text != work.expected?.text,
    _ => false,
  };

  /// The state with the editing phase the work shows.
  FileState get shown => switch (status) {
    Editing() => state.copyWith(
      status: Editing(switch ((work.io, work.draft)) {
        (WritingFile(:final text), _) when text == state.text =>
          EditPhase.writing,
        (_, KeptDraft(:final text)) when text == state.text =>
          EditPhase.onDevice,
        _ => EditPhase.inMemory,
      }),
    ),
    _ => state,
  };

  void handle(FileInput input) {
    switch (input) {
      case Edited():
        _edited(input);
      case SaveNow():
        _saveNow();
      case Secure(:final reason):
        _secure(reason);
      case Observed(:final observation, :final startedAt):
        _observed(observation, startedAt);
      case Pick():
        _pick(input);
      case RestoreMine():
        _restoreMine();
      case Discard():
        _discard();
      case Moved(:final copy):
        _moved(copy);
      case DraftKept(:final id, :final kept):
        _draftKept(id, kept: kept);
      case Wrote(:final id, :final outcome, :final endedAt):
        _wrote(id, outcome, endedAt);
      case BackedUp(:final id, :final ok):
        _backedUp(id, ok: ok);
      case ConflictKept(:final id, :final ok):
        _conflictKept(id, ok: ok);
    }
    _next();
  }

  // The next I/O.

  /// Starts the next I/O once none is under way: a pick waiting, the
  /// next step of a [Secure], the draft, then the file.
  void _next() {
    if (work.io != null) return;
    if (work.pick case final pick?) _startPick(pick);
    if (work.securing case final securing? when work.io == null) {
      _secureStep(securing);
    }
    if (work.io != null) return;
    if (!_hasEdits && work.draft != null) _dropDraft();
    if (_hasEdits && work.draft?.text != state.text) return _keepDraft();
    if (work.folderRev != null) _write();
  }

  // Edits.

  void _edited(Edited edited) {
    // Made before a pick the editor shows instead.
    if (_done || edited.picks < work.picks) return;
    final sent = work.sent;
    final over = work.offered.indexWhere(
      (seen) => seen.version == edited.lineage,
    );
    if (over >= 0) _work(work.copyWith(offered: work.offered.sublist(over)));
    if (sent != null && edited.lineage != sent.version) {
      // Made on a version the editor did not take: the user picks.
      if (over >= 0) _work(work.copyWith(editsOver: work.offered.first));
      _set(text: edited.text, rev: edited.rev);
      if (status is! ChangedElsewhere) _set(status: ChangedElsewhere(sent));
      return;
    }
    if (edited.text == state.text) return _set(rev: edited.rev);
    _set(text: edited.text, rev: edited.rev);
    switch (status) {
      case ChangedElsewhere() || DeletedElsewhere():
        break;
      case _ when work.expected == null && edited.text.trim().isEmpty:
        _settle(const Unwritten());
      case _ when edited.text == work.expected?.text && work.io is! WritingFile:
        // Back to the file's text: nothing to write.
        _settle(const InStep());
      case _:
        _set(status: const Editing(EditPhase.inMemory));
    }
  }

  /// Asks the file to hold the edits, where they can be written there.
  void _saveNow() {
    if (work.expected != null && (status is Editing || status is SaveFailed)) {
      _askFolder();
    }
  }

  /// The file is asked to hold the edits as they are now.
  void _askFolder() => _work(work.copyWith(folderRev: state.rev));

  // Drafts.

  void _keepDraft() {
    final id = _id();
    _work(work.copyWith(io: KeepingDraft(id, state.text)));
    outputs.add(
      KeepDraft(
        id,
        base: (work.editsOver ?? work.expected)?.text,
        text: state.text,
      ),
    );
  }

  void _draftKept(EffectId id, {required bool kept}) {
    if (work.io case KeepingDraft(id: final keeping, :final text)
        when keeping == id) {
      _work(
        work.copyWith(
          io: null,
          draft: kept ? KeptDraft(text) : RefusedDraft(text),
        ),
      );
      // The device cannot keep them: into the file now, unless a Secure
      // decides where they go.
      if (!kept && work.securing == null) _saveNow();
    }
  }

  void _dropDraft() {
    _work(work.copyWith(draft: null));
    outputs.add(const DropDraft());
  }

  /// No edits are pending any more: in the file, in a conflict copy, or
  /// dropped. The draft goes once no I/O is under way.
  void _settle(FileStatus settled) {
    _work(work.copyWith(editsOver: null));
    _set(status: settled);
  }

  // Writes.

  /// Writes the edits the file is asked to hold, once the device keeps
  /// them (or could not).
  void _write() {
    final kind = switch (status) {
      DeletedElsewhere() => WriteKind.restore,
      Editing() || SaveFailed() when work.expected == null => WriteKind.create,
      Editing() || SaveFailed() => WriteKind.write,
      _ => null,
    };
    if (kind != null) _startWrite(state.text, rev: state.rev, kind: kind);
  }

  void _startWrite(String text, {required int rev, required WriteKind kind}) {
    final id = _id();
    final expected = work.expected;
    final backUp =
        kind != WriteKind.restore &&
        expected != null &&
        expected.text != work.backedUp;
    _work(
      work.copyWith(
        io: WritingFile(id, text, rev: rev, kind: kind),
        backedUp: backUp ? expected.text : work.backedUp,
      ),
    );
    outputs.add(switch ((kind, expected)) {
      (WriteKind.create, _) => Create(id, text),
      (WriteKind.restore, _) => Restore(id, text),
      (WriteKind.write || WriteKind.rewrite, final over?) => Write(
        id,
        text,
        over: over,
        backUpFirst: backUp,
      ),
      (WriteKind.write || WriteKind.rewrite, null) => throw StateError(
        'a write needs a file to go over',
      ),
    });
  }

  void _wrote(EffectId id, WriteOutcome outcome, Moment endedAt) {
    final writing = switch (work.io) {
      final WritingFile writing when writing.id == id => writing,
      _ => null,
    };
    if (writing == null) return;
    _work(work.copyWith(io: null, lastWriteEnd: endedAt));
    switch (outcome) {
      case Written(:final seen):
        _written(writing, seen);
      case Changed(:final theirs)
          when writing.kind == WriteKind.write &&
              theirs.text == work.expected?.text:
        // Only restamped: write again over the new stamp.
        _work(work.copyWith(expected: theirs));
        _startWrite(writing.text, rev: writing.rev, kind: WriteKind.rewrite);
      case Changed(:final theirs) when theirs.text == state.text:
        _inStep(theirs);
      case Changed(:final theirs):
        _set(status: ChangedElsewhere(theirs));
      case Taken(:final there) when work.expected != null:
        _cameBack(there);
      case Taken():
        throw StateError('a new document takes the next free name');
      case WriteGone():
        _goneElsewhere();
      case WriteFailed():
        // Tried again only when asked again.
        _set(status: const SaveFailed());
        _work(work.copyWith(folderRev: null));
        if (work.securing case (:final reasons, rung: SecureRung.file)) {
          _work(
            work.copyWith(
              securing: (reasons: reasons, rung: SecureRung.device),
            ),
          );
        }
    }
    _takeMove();
  }

  void _written(WritingFile writing, Seen seen) {
    _work(
      work.copyWith(
        expected: seen,
        backedUp: writing.text,
        folderRev: switch (work.folderRev) {
          final asked? when asked > writing.rev => asked,
          _ => null,
        },
      ),
    );
    if (writing.text == state.text) {
      _settle(const InStep());
    } else if (status is! ChangedElsewhere) {
      // Edits made meanwhile wait to be written.
      _set(status: const Editing(EditPhase.inMemory));
    }
  }

  void _restoreMine() {
    if (status is DeletedElsewhere) _askFolder();
  }

  // Changes elsewhere.

  void _observed(Observation observation, Moment startedAt) {
    if (_done || work.expected == null) return;
    // A scan during our write, or one that started before it ended, may
    // hold the old version.
    if (work.io is WritingFile || work.io is KeepingConflict) return;
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
      case ChangedElsewhere()
          when work.editsOver == null &&
              (latest.version == expected.version ||
                  latest.text == expected.text):
        // Changed back to the version the edits were made over.
        _work(work.copyWith(expected: latest));
        _set(status: const Editing(EditPhase.inMemory));
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
      // The version the edits were made over: they wait to be written.
      _set(status: const Editing(EditPhase.inMemory));
    } else {
      _set(status: ChangedElsewhere(latest));
    }
  }

  /// The editor shows [latest], unless it has edits not seen here.
  void _replaced(Seen latest) {
    _work(work.copyWith(expected: latest, offered: [...work.offered, latest]));
    _set(text: latest.text, status: const InStep());
    outputs.add(
      Replaced(latest.text, version: latest.version, ackRev: state.rev),
    );
  }

  void _goneElsewhere() {
    if (status is! DeletedElsewhere) _set(status: const DeletedElsewhere());
  }

  void _inStep(Seen latest) {
    _work(work.copyWith(expected: latest));
    _settle(const InStep());
  }

  void _moved(Seen copy) {
    // A copy that differs changed before the move: writes stay over the
    // version expected, so they find that change, as a scan does.
    if (copy.text != work.expected?.text) return;
    // A write under way answers for the file before the move.
    _work(
      work.io is WritingFile
          ? work.copyWith(moved: copy)
          : work.copyWith(expected: copy),
    );
  }

  /// The copy a move left while a write was under way, now that it ended:
  /// what writes go over, and written again where it lacks the edits.
  void _takeMove() {
    final copy = work.moved;
    if (copy == null) return;
    _work(work.copyWith(moved: null, expected: copy));
    if (status is InStep && copy.text != state.text) {
      _set(status: const Editing(EditPhase.inMemory));
      _askFolder();
    }
  }

  // Picks.

  /// Takes [pick] between the edits as they are and the version from
  /// elsewhere waiting for it; the backup follows the I/O under way.
  void _pick(Pick pick) {
    if (_theirs(pick) != null &&
        pick.rev == state.rev &&
        work.pick == null &&
        work.io is! BackingUp) {
      _work(work.copyWith(pick: pick));
    }
  }

  /// The version from elsewhere [pick] is against, while it waits for
  /// the pick.
  Seen? _theirs(Pick pick) => switch (status) {
    ChangedElsewhere(:final theirs) when theirs.version == pick.seen => theirs,
    _ => null,
  };

  void _startPick(Pick pick) {
    _work(work.copyWith(pick: null));
    if (_theirs(pick) case final theirs?) {
      final id = _id();
      _work(work.copyWith(io: BackingUp(id, pick)));
      outputs.add(BackUpBoth(id, theirs: theirs, mine: state.text));
    } else {
      outputs.add(const PickNotKept());
    }
  }

  void _backedUp(EffectId id, {required bool ok}) {
    final pick = switch (work.io) {
      BackingUp(id: final backingUp, :final pick) when backingUp == id => pick,
      _ => null,
    };
    if (pick == null) return;
    _work(work.copyWith(io: null));
    final theirs = _theirs(pick);
    // Theirs would drop edits made since the pick.
    final dropsEdits =
        pick.choice == PickChoice.theirs && pick.rev != state.rev;
    if (!ok || theirs == null || dropsEdits) {
      // No backup, their version changed again, or the conflict is gone.
      return outputs.add(const PickNotKept());
    }
    _work(
      work.copyWith(expected: theirs, editsOver: null, backedUp: theirs.text),
    );
    switch (pick.choice) {
      case PickChoice.mine:
        // The editor shows mine already and goes on on its version.
        _work(work.copyWith(offered: work.offered.take(1).toList()));
        _set(status: const Editing(EditPhase.inMemory));
        _askFolder();
      case PickChoice.theirs:
        _work(work.copyWith(offered: [theirs]));
        _set(text: theirs.text);
        _picked(theirs.text, theirs.version);
        _settle(const InStep());
    }
  }

  /// Drops the edits that could be kept nowhere: the text goes back to
  /// the file's. Not while they may still reach the file or a pick.
  void _discard() {
    final keptNowhere = switch (status) {
      SaveFailed() || ChangedElsewhere() || DeletedElsewhere() => true,
      _ => false,
    };
    final mayReachFile = work.io is WritingFile || work.io is BackingUp;
    if (!keptNowhere || mayReachFile || work.pick != null) return;
    final expected = work.expected;
    _work(work.copyWith(offered: [?expected]));
    _set(text: expected?.text ?? '');
    _picked(state.text, expected?.version);
    _settle(switch (status) {
      DeletedElsewhere() => const DeletedElsewhere(),
      _ when expected == null => const Unwritten(),
      _ => const InStep(),
    });
  }

  void _picked(String text, Version? version) {
    _work(work.copyWith(picks: work.picks + 1));
    outputs.add(Picked(text, version: version, rev: state.rev));
  }

  // Securing.

  void _secure(SecureReason reason) {
    final securing = work.securing;
    _work(
      work.copyWith(
        securing: (
          reasons: [...?securing?.reasons, reason],
          rung: securing?.rung ?? SecureRung.file,
        ),
      ),
    );
  }

  /// The next step to keep the edits somewhere lasting, while no I/O is
  /// under way: the file, else the device (unless a document with a file
  /// closes), else a conflict copy next to the file.
  void _secureStep(Securing securing) {
    final closing = securing.reasons.contains(SecureReason.close);
    final hasFile = work.expected != null;
    switch (securing.rung) {
      case _ when !_hasEdits:
        _answer(kept: true);
      case SecureRung.file when status is Editing || status is SaveFailed:
        if (work.folderRev == null) _askFolder();
      case SecureRung.file || SecureRung.device when !closing || !hasFile:
        _secureOnDevice(securing, closing: closing);
      case _ when hasFile:
        _keepAsConflict();
      case _:
        _answer(kept: false);
    }
  }

  /// The edits wait on the device for the user to pick or write them; a
  /// new document closed there is not kept lasting.
  void _secureOnDevice(Securing securing, {required bool closing}) {
    switch (work.draft) {
      case KeptDraft(:final text) when text == state.text:
        _answer(kept: !closing);
      case RefusedDraft(:final text) when text == state.text:
        _secureStep((reasons: securing.reasons, rung: SecureRung.conflict));
      case _:
        // Kept by [_next] first.
        _work(
          work.copyWith(
            securing: (reasons: securing.reasons, rung: SecureRung.device),
          ),
        );
    }
  }

  void _keepAsConflict() {
    final id = _id();
    _work(work.copyWith(io: KeepingConflict(id, before: status)));
    // Set before the copy is written, so no edit can slip past it.
    _set(status: const KeptAsConflict());
    outputs.add(KeepAsConflict(id, state.text));
  }

  void _conflictKept(EffectId id, {required bool ok}) {
    final before = switch (work.io) {
      KeepingConflict(id: final keeping, :final before) when keeping == id =>
        before,
      _ => null,
    };
    if (before == null) return;
    _work(work.copyWith(io: null));
    _takeMove();
    // Not kept: on the device at least, and the next start tries again.
    if (!ok) _set(status: before);
    if (work.securing != null) _answer(kept: ok);
  }

  /// Answers every [Secure] waiting.
  void _answer({required bool kept}) {
    final reasons = work.securing!.reasons;
    _work(work.copyWith(securing: null));
    outputs.addAll([for (final reason in reasons) Answer(reason, kept: kept)]);
    if (kept && reasons.contains(SecureReason.close)) {
      _set(status: const Closed());
    }
  }

  // State.

  EffectId _id() {
    final id = EffectId(work.nextId);
    _work(work.copyWith(nextId: work.nextId + 1));
    return id;
  }

  void _work(FileWork next) => work = next;

  /// Sets the state; a status the edits can't be written in drops the
  /// write asked.
  void _set({FileStatus? status, String? text, int? rev}) {
    state = state.copyWith(status: status, text: text, rev: rev);
    if (status != null && status is! Editing && status is! SaveFailed) {
      _work(work.copyWith(folderRev: null));
    }
  }
}
