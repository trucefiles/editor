import '../../common/moment.dart';
import '../../owners/effects.dart';
import '../../owners/machine.dart';
import '../version.dart';
import 'file_contract.dart';
import 'file_state.dart';
import 'file_work.dart';

/// The file owner's decision on [message] in [state], with its [work].
Step<FileState<V>, FileWork<V>, FileEvent, FileEffect<V>> fileStep<
  V extends Version
>(FileState<V> state, FileWork<V> work, FileMessage<V> message) {
  final step = _Step(state, work)..handle(message);
  return (
    state: step.shown,
    work: step.work,
    events: step.events,
    effects: step.effects,
  );
}

/// One input's handling: the state as it changes and what it leads to.
/// Inputs update what is known and asked; [_next] then starts the next
/// I/O once none is under way.
final class _Step<V extends Version> {
  _Step(this.state, this.work);

  FileState<V> state;
  FileWork<V> work;
  final events = <FileEvent>[];
  final effects = <FileEffect<V>>[];
  FileStatus<V> get status => state.status;

  bool get _done => status is KeptAsConflict || status is Closed;

  /// Whether there are edits the file does not hold.
  bool get _hasEdits => switch (status) {
    Editing() || SaveFailed() => true,
    ChangedElsewhere() ||
    DeletedElsewhere() => state.text != work.expected?.text,
    _ => false,
  };

  /// The state with the editing phase and the file the work shows.
  FileState<V> get shown => FileState(
    status: switch (status) {
      Editing() => Editing(switch ((work.io, work.draft)) {
        (WritingFile(:final text), _) when text == state.text =>
          EditPhase.writing,
        (_, KeptDraft(:final text)) when text == state.text =>
          EditPhase.onDevice,
        _ => EditPhase.inMemory,
      }),
      _ => status,
    },
    text: state.text,
    rev: state.rev,
    file: _file,
  );

  /// The version of the file the edits go over; `null` while a new
  /// document has no file.
  V? get _file => work.expected?.version;

  void handle(FileMessage<V> message) {
    switch (message) {
      case Edited():
        _edited(message);
      case SaveNow():
        _saveNow();
      case Secure():
        _secure(message);
      case Observed(:final observation, :final startedAt):
        _observed(observation, startedAt);
      case Pick():
        _pick(message);
      case RestoreMine():
        _restoreMine();
      case Discard():
        _discard();
      case Move():
        _move(message);
      case DraftKept(:final id, :final kept):
        _draftKept(id, kept: kept);
      case Wrote(:final id, :final outcome, :final endedAt):
        _wrote(id, outcome, endedAt);
      case BackedUp(:final id, :final ok):
        _backedUp(id, ok: ok);
      case ConflictKept(:final id, :final ok):
        _conflictKept(id, ok: ok);
      case LatestRead(:final id, :final seen):
        _latestRead(id, seen);
      case MovedTo(:final id, :final copy, :final endedAt):
        _movedTo(id, copy, endedAt);
    }
    _next();
  }

  // The next I/O.

  /// Starts the next I/O once none is under way: a pick waiting, the
  /// next step of a move waiting, the next step of a [Secure], a version
  /// found to read, the draft, then the file.
  void _next() {
    if (work.io != null) return;
    if (work.pick case final pick?) _startPick(pick);
    // Dropped while it still names the file it was kept for, before a move.
    if (work.io == null && !_hasEdits && work.draft != null) _dropDraft();
    if (work.move case final move? when work.io == null) _moveStep(move);
    // Secures waiting are answered once the move ran.
    if (work.securing case final securing?
        when work.io == null && work.move == null) {
      _secureStep(securing);
    }
    if (work.io != null) return;
    if (work.toRead != null && !_done) return _readLatest();
    if (_hasEdits && work.draft?.text != state.text) return _keepDraft();
    if (work.folderRev != null) _write();
  }

  // Edits.

  void _edited(Edited edited) {
    // Made before a pick the editor shows instead.
    if (_done || edited.picks < work.picks) return;
    final sent = work.sent;
    // Edits that name no version build on the file this owner created.
    final lineage = edited.lineage ?? work.created;
    final over = work.offered.indexWhere((seen) => seen.version == lineage);
    if (over >= 0) _work(work.copyWith(offered: work.offered.sublist(over)));
    if (sent != null && lineage != sent.version) {
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
    effects.add(
      KeepDraft(
        id,
        base: (work.editsOver ?? work.expected)?.text,
        text: state.text,
        file: _file,
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
    effects.add(DropDraft(file: _file));
  }

  /// No edits are pending any more: in the file, in a conflict copy, or
  /// dropped. The draft goes once no I/O is under way.
  void _settle(FileStatus<V> settled) {
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
    effects.add(switch ((kind, expected)) {
      (WriteKind.create, _) => Create(id, text),
      (WriteKind.restore, final where?) => Restore(id, text, where: where),
      (WriteKind.restore, null) => throw StateError(
        'a restore needs the file it was',
      ),
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

  void _wrote(EffectId id, WriteOutcome<V> outcome, Moment endedAt) {
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
        if (work.securing case (:final asks, rung: SecureRung.file)) {
          _work(work.copyWith(securing: (asks: asks, rung: SecureRung.device)));
        }
    }
  }

  void _written(WritingFile writing, Seen<V> seen) {
    if (writing.kind == WriteKind.create) {
      // The editor builds on the created file until it takes another.
      _work(work.copyWith(offered: [seen], created: seen.version));
    }
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
    if (work.io is WritingFile ||
        work.io is KeepingConflict ||
        work.io is MovingFile) {
      return;
    }
    if (work.lastWriteEnd case final end? when startedAt.isBefore(end)) {
      return;
    }
    switch (observation) {
      case Unknown():
        break;
      case Gone():
        _work(work.copyWith(toRead: null));
        _goneElsewhere();
      case Found(:final version):
        _foundVersion(version);
    }
  }

  /// The file is there in [version]: known already, or read before it
  /// counts.
  void _foundVersion(Version version) {
    final known = [
      work.expected,
      if (status case ChangedElsewhere(:final theirs)) theirs,
      ...work.offered,
    ].nonNulls.where((seen) => seen.version == version).firstOrNull;
    if (known == null) return _work(work.copyWith(toRead: version));
    _work(work.copyWith(toRead: null));
    _found(known);
  }

  void _readLatest() {
    final id = _id();
    final at = work.expected!;
    _work(work.copyWith(io: ReadingFile(id, at: at), toRead: null));
    effects.add(ReadLatest(id, at: at));
  }

  void _latestRead(EffectId id, Seen<V>? seen) {
    final reading = switch (work.io) {
      final ReadingFile reading when reading.id == id => reading,
      _ => null,
    };
    if (reading == null) return;
    _work(work.copyWith(io: null));
    // Read where the file no longer is (moved meanwhile): the next
    // observation tells of the file where it is now.
    if (seen == null || work.expected != reading.at || _done) return;
    if (work.toRead == seen.version) _work(work.copyWith(toRead: null));
    _found(seen);
  }

  void _found(Seen<V> latest) {
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
  void _cameBack(Seen<V> latest) {
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
  void _replaced(Seen<V> latest) {
    _work(work.copyWith(expected: latest, offered: [...work.offered, latest]));
    _set(text: latest.text, status: const InStep());
    events.add(
      Replaced(latest.text, version: latest.version, ackRev: state.rev),
    );
  }

  void _goneElsewhere() {
    if (status is! DeletedElsewhere) _set(status: const DeletedElsewhere());
  }

  void _inStep(Seen<V> latest) {
    _work(work.copyWith(expected: latest));
    _settle(const InStep());
  }

  // Moves.

  /// Takes [move], one at a time; a failed write is tried once more.
  void _move(Move move) {
    if (work.move != null || work.io is MovingFile) {
      return events.add(MoveAnswer(move.ticket, started: false));
    }
    _work(work.copyWith(move: move));
    _saveNow();
  }

  /// The next step of [move]: the file holds the edits, so it moves; or
  /// the edits are written first; or they can't reach the file, so it
  /// stays.
  void _moveStep(Move move) {
    final from = work.expected;
    switch (status) {
      // A version found is read first: a move goes only from the file now.
      case InStep() when work.toRead != null:
        break;
      case InStep() when from != null:
        _work(work.copyWith(move: null));
        final id = _id();
        _work(work.copyWith(io: MovingFile(id, move)));
        effects.add(MoveFile(id, ticket: move.ticket, from: from));
      case Editing() when from != null:
        _askFolder();
      // Tried once more when the move was asked.
      case SaveFailed() when work.folderRev != null:
        break;
      case _:
        _work(work.copyWith(move: null));
        events.add(MoveAnswer(move.ticket, started: false));
    }
  }

  /// The move ended: writes go over the [copy] it left, edits made
  /// meanwhile too.
  void _movedTo(EffectId id, Seen<V>? copy, Moment endedAt) {
    final ask = switch (work.io) {
      MovingFile(id: final moving, :final ask) when moving == id => ask,
      _ => null,
    };
    if (ask == null) return;
    _work(work.copyWith(io: null));
    if (copy != null) {
      _work(work.copyWith(expected: copy, lastWriteEnd: endedAt));
    }
    events.add(MoveAnswer(ask.ticket, started: true));
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
  Seen<V>? _theirs(Pick pick) => switch (status) {
    ChangedElsewhere(:final theirs) when theirs.version == pick.seen => theirs,
    _ => null,
  };

  void _startPick(Pick pick) {
    _work(work.copyWith(pick: null));
    if (_theirs(pick) case final theirs?) {
      final id = _id();
      _work(work.copyWith(io: BackingUp(id, pick)));
      effects.add(BackUpBoth(id, theirs: theirs, mine: state.text));
    } else {
      events.add(const PickNotKept());
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
    if (!ok || theirs == null || work.toRead != null || dropsEdits) {
      // No backup, their version changed again (perhaps not read yet), or
      // the conflict is gone.
      return events.add(const PickNotKept());
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

  /// Drops the edits that are in no file: the text goes back to the
  /// file's, as it is now. Not while they may still reach the file or a
  /// pick.
  void _discard() {
    final inNoFile = switch (status) {
      SaveFailed() || ChangedElsewhere() || DeletedElsewhere() => true,
      Editing() => work.expected == null,
      _ => false,
    };
    final mayReachFile = work.io is WritingFile || work.io is BackingUp;
    if (!inNoFile || mayReachFile || work.pick != null) return;
    final file = switch (status) {
      ChangedElsewhere(:final theirs) => theirs,
      _ => work.expected,
    };
    _work(work.copyWith(expected: file, offered: [?file]));
    _set(text: file?.text ?? '');
    _picked(state.text, file?.version);
    _settle(switch (status) {
      DeletedElsewhere() => const DeletedElsewhere(),
      _ when file == null => const Unwritten(),
      _ => const InStep(),
    });
  }

  void _picked(String text, Version? version) {
    _work(work.copyWith(picks: work.picks + 1));
    events.add(Picked(text, version: version, rev: state.rev));
  }

  // Securing.

  void _secure(Secure secure) {
    final securing = work.securing;
    _work(
      work.copyWith(
        securing: (
          asks: [...?securing?.asks, secure],
          rung: securing?.rung ?? SecureRung.file,
        ),
      ),
    );
  }

  /// The next step to keep the edits somewhere lasting, while no I/O is
  /// under way: the file, else the device (unless a document with a file
  /// closes), else a conflict copy next to the file.
  void _secureStep(Securing securing) {
    final closing = securing.asks.any(
      (secure) => secure.reason == SecureReason.close,
    );
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
        _secureStep((asks: securing.asks, rung: SecureRung.conflict));
      case _:
        // Kept by [_next] first.
        _work(
          work.copyWith(
            securing: (asks: securing.asks, rung: SecureRung.device),
          ),
        );
    }
  }

  void _keepAsConflict() {
    final id = _id();
    _work(work.copyWith(io: KeepingConflict(id, before: status)));
    // Set before the copy is written, so no edit can slip past it.
    _set(status: const KeptAsConflict());
    effects.add(KeepAsConflict(id, state.text, nextTo: work.expected!));
  }

  void _conflictKept(EffectId id, {required bool ok}) {
    final before = switch (work.io) {
      KeepingConflict(id: final keeping, :final before) when keeping == id =>
        before,
      _ => null,
    };
    if (before == null) return;
    _work(work.copyWith(io: null));
    // Not kept: on the device at least, and the next start tries again.
    if (!ok) _set(status: before);
    if (work.securing != null) _answer(kept: ok);
  }

  /// Answers every [Secure] waiting.
  void _answer({required bool kept}) {
    final asks = work.securing!.asks;
    _work(work.copyWith(securing: null));
    events.addAll([for (final ask in asks) Answer(ask.ticket, kept: kept)]);
    if (kept && asks.any((ask) => ask.reason == SecureReason.close)) {
      _set(status: const Closed());
    }
  }

  // State.

  EffectId _id() {
    final id = EffectId(work.nextId);
    _work(work.copyWith(nextId: work.nextId + 1));
    return id;
  }

  void _work(FileWork<V> next) => work = next;

  /// Sets the state; a status the edits can't be written in drops the
  /// write asked.
  void _set({FileStatus<V>? status, String? text, int? rev}) {
    state = state.copyWith(status: status, text: text, rev: rev);
    if (status != null && status is! Editing && status is! SaveFailed) {
      _work(work.copyWith(folderRev: null));
    }
  }
}
