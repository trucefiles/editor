import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

extension on Editing {
  /// Matches an [Editing] in this phase.
  Matcher get matcher =>
      isA<Editing>().having((editing) => editing.phase, 'phase', phase);
}

const _v1 = Version(1);
const _v2 = Version(2);
const _v3 = Version(3);

/// A file machine with what it led to so far.
final class _Run {
  _Run(FileMachine machine) : machine = MachineRun.of(machine);

  _Run.opened(String text) : this(openedFile(Seen(text, _v1)));

  _Run.unwritten() : this(newFile());

  final MachineRun<FileMessage, FileState, FileEvent, FileEffect> machine;

  FileState get state => machine.state;

  FileStatus get status => state.status;

  T last<T>() => machine.last<T>();

  List<T> all<T>() => machine.all<T>();

  /// What the file holds for a read the owner starts: the last [found].
  Seen? _file;

  /// Sends [message]; a read it starts reads what [found] last found.
  void send(FileMessage message) {
    for (final read in machine.send(message).whereType<ReadLatest>()) {
      send(LatestRead(read.id, _file));
    }
  }

  /// Asks to keep the edits for [reason]; its ticket.
  Ticket secure(SecureReason reason) {
    final ticket = Ticket();
    send(Secure(ticket, reason));
    return ticket;
  }

  /// The editor's text at [rev], on [lineage], after [picks] picks (by
  /// default all sent so far).
  void edit(String text, int rev, {Version? lineage = _v1, int? picks}) => send(
    Edited(
      text,
      rev: rev,
      lineage: lineage,
      picks: picks ?? all<Picked>().length,
    ),
  );

  /// The device keeps the last draft asked (or refuses it).
  void keep({bool kept = true}) =>
      send(DraftKept(last<KeepDraft>().id, kept: kept));

  /// The editor's text at [rev], kept as the draft, then asked into the
  /// file.
  void save(String text, int rev) {
    edit(text, rev);
    keep();
    send(const SaveNow());
  }

  void wrote(WriteOutcome outcome) {
    final id = switch (machine.effects.lastWhere(
      (effect) => effect is Write || effect is Create || effect is Restore,
    )) {
      Write(:final id) || Create(:final id) || Restore(:final id) => id,
      _ => throw StateError('no write'),
    };
    send(Wrote(id, outcome, endedAt: Moment.now()));
  }

  /// Asks to move the file; the app moves it, as the move asked last, to
  /// [copy] (`null`: it did not move).
  void move(Seen? copy) {
    send(Move(Ticket()));
    if (machine.effects.lastOrNull case MoveFile(:final id)) {
      send(MovedTo(id, copy, endedAt: Moment.now()));
    }
  }

  /// A scan found the file in [seen]'s version, holding [seen]'s text
  /// for the reads that follow.
  void found(Seen seen, {Moment? startedAt}) {
    _file = seen;
    send(Observed(Found(seen.version), startedAt: startedAt ?? Moment.now()));
  }
}

void main() {
  group('saving', () {
    test('keeps edits on the device at once, then writes them when asked', () {
      final run = _Run.opened('a')..edit('ab', 1);
      expect(run.status, const Editing(EditPhase.inMemory).matcher);
      expect(run.last<KeepDraft>().base, 'a');
      expect(run.last<KeepDraft>().text, 'ab');
      run.keep();
      expect(run.status, const Editing(EditPhase.onDevice).matcher);
      run.send(const SaveNow());
      final write = run.last<Write>();
      expect(
        (write.text, write.over.version, write.backUpFirst),
        ('ab', _v1, true),
      );
      expect(run.status, const Editing(EditPhase.writing).matcher);
      run.wrote(const Written(Seen('ab', _v2)));
      expect(run.status, isA<InStep>());
      expect(run.all<DropDraft>(), hasLength(1));
    });

    test('runs one I/O at a time: edits during a keep are kept after it', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..edit('abc', 2);
      expect(run.all<KeepDraft>(), hasLength(1));
      run.keep();
      expect(run.last<KeepDraft>().text, 'abc');
      expect(run.all<KeepDraft>(), hasLength(2));
    });

    test('writes into the file only once the latest edits are kept', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..send(const SaveNow())
        ..edit('abc', 2);
      expect(run.all<Write>(), isEmpty);
      run.keep();
      expect(run.all<Write>(), isEmpty, reason: 'abc is being kept');
      run.keep();
      expect(run.last<Write>().text, 'abc');
    });

    test('a move asked during a write runs once the edits are in', () {
      final run = _Run.opened('a')
        ..save('ab', 1)
        ..send(Move(Ticket()));
      expect(run.all<MoveFile>(), isEmpty);
      run.wrote(const Written(Seen('ab', _v2)));
      expect(run.last<MoveFile>().from.version, _v2);
    });

    test('a move writes the edits not in the file yet first', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..keep()
        ..send(Move(Ticket()));
      expect(run.all<MoveFile>(), isEmpty);
      expect(run.last<Write>().text, 'ab');
      run.wrote(const Written(Seen('ab', _v2)));
      expect(run.last<MoveFile>().from.version, _v2);
    });

    test('a close asked after a move is answered once the move ran', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..send(Move(Ticket()))
        ..secure(SecureReason.close)
        ..keep()
        ..wrote(const Written(Seen('ab', _v2)));
      expect(run.all<Answer>(), isEmpty);
      final move = run.last<MoveFile>();
      run.send(MovedTo(move.id, const Seen('ab', _v3), endedAt: Moment.now()));
      expect(run.last<MoveAnswer>().started, isTrue);
      expect(run.last<Answer>().kept, isTrue);
      expect(run.status, isA<Closed>());
    });

    test('edits that could not be written refuse a move', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..keep()
        ..send(Move(Ticket()))
        ..wrote(const WriteFailed());
      expect(run.all<MoveFile>(), isEmpty);
      expect(run.last<MoveAnswer>().started, isFalse);
    });

    test('a move after a failed write tries the write once more', () {
      final run = _Run.opened('a')
        ..save('ab', 1)
        ..wrote(const WriteFailed())
        ..send(Move(Ticket()));
      expect(run.all<Write>(), hasLength(2));
      run.wrote(const Written(Seen('ab', _v2)));
      expect(run.last<MoveFile>().from.version, _v2);
    });

    test('a close waiting behind a refused move still keeps the edits', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..send(Move(Ticket()))
        ..secure(SecureReason.close)
        ..keep()
        ..wrote(const WriteFailed());
      expect(run.last<MoveAnswer>().started, isFalse);
      // The secure tries the file once more, then keeps a conflict copy.
      run
        ..wrote(const WriteFailed())
        ..send(ConflictKept(run.last<KeepAsConflict>().id, ok: true));
      expect(run.last<Answer>().kept, isTrue);
    });

    test('a new document without a file refuses a move', () {
      final run = _Run.unwritten()
        ..edit('ab', 1)
        ..send(Move(Ticket()))
        ..keep();
      expect(run.all<MoveFile>(), isEmpty);
      expect(run.last<MoveAnswer>().started, isFalse);
    });

    test('a change elsewhere refuses a move', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..keep()
        ..send(Move(Ticket()))
        ..wrote(const Changed(Seen('b', _v2)));
      expect(run.all<MoveFile>(), isEmpty);
      expect(run.last<MoveAnswer>().started, isFalse);
    });

    test('edits made during a move are written over the copy', () {
      const copy = Seen('a', Version(9));
      final run = _Run.opened('a')..send(Move(Ticket()));
      final move = run.last<MoveFile>();
      run
        ..edit('ab', 1)
        ..send(MovedTo(move.id, copy, endedAt: Moment.now()))
        ..keep()
        ..send(const SaveNow());
      expect(run.last<MoveAnswer>().started, isTrue);
      final write = run.last<Write>();
      expect((write.text, write.over), ('ab', copy));
    });

    test('a scan during a move changes nothing', () {
      final run = _Run.opened('a')..send(Move(Ticket()));
      final move = run.last<MoveFile>();
      run
        ..send(Observed(const Gone(), startedAt: Moment.now()))
        ..send(MovedTo(move.id, const Seen('a', _v2), endedAt: Moment.now()));
      expect(run.status, isA<InStep>());
      expect(run.state.file, _v2);
    });

    test('edits made during a write are kept after it, then written when '
        'asked, without a backup', () {
      final run = _Run.opened('a')
        ..save('ab', 1)
        ..edit('abc', 2);
      expect(
        run.status,
        const Editing(EditPhase.inMemory).matcher,
        reason: 'the latest edits are not on the device yet',
      );
      expect(run.all<KeepDraft>(), hasLength(1), reason: 'after the write');
      run.wrote(const Written(Seen('ab', _v2)));
      expect(run.last<KeepDraft>().text, 'abc');
      expect(run.all<Write>(), hasLength(1));
      run
        ..keep()
        ..send(const SaveNow());
      final write = run.last<Write>();
      expect(
        (write.text, write.over.version, write.backUpFirst),
        ('abc', _v2, false),
      );
    });

    test('a write asked during a write holds the edits as asked', () {
      final run = _Run.opened('a')
        ..save('ab', 1)
        ..edit('abc', 2)
        ..send(const SaveNow())
        ..wrote(const Written(Seen('ab', _v2)))
        ..keep();
      expect(run.last<Write>().text, 'abc');
    });

    test('no write once the file holds what was asked', () {
      final run = _Run.opened('a')
        ..send(const SaveNow())
        ..save('ab', 1)
        ..wrote(const Written(Seen('ab', _v2)))
        ..send(const SaveNow())
        ..edit('abc', 2)
        ..keep();
      expect(run.all<Write>(), hasLength(1));
    });

    test('edits back to the file\'s text leave nothing to write', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..edit('a', 2)
        ..keep()
        ..send(const SaveNow());
      expect(run.status, isA<InStep>());
      expect(run.all<Write>(), isEmpty);
      expect(run.all<DropDraft>(), hasLength(1));
    });

    test('writes into the file now when the device cannot keep the edits', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..keep(kept: false);
      expect(run.last<Write>().text, 'ab');
      expect(run.status, const Editing(EditPhase.writing).matcher);
    });

    test('a file only restamped at a write is written once more', () {
      final run = _Run.opened('a')
        ..save('ab', 1)
        ..wrote(const Changed(Seen('a', _v2)));
      expect(run.last<Write>().over.version, _v2);
      run.wrote(const Changed(Seen('a', _v3)));
      expect(run.status, isA<ChangedElsewhere>());
    });

    test('a failed write keeps the edits, tried again when asked', () {
      final run = _Run.opened('a')
        ..save('ab', 1)
        ..wrote(const WriteFailed());
      expect(run.status, isA<SaveFailed>());
      expect(run.all<Write>(), hasLength(1));
      run.edit('abc', 2);
      expect(run.last<KeepDraft>().text, 'abc');
      run
        ..keep()
        ..send(const SaveNow());
      expect(run.last<Write>().text, 'abc');
    });
  });

  group('changes elsewhere', () {
    test('a version found is read by the owner before it counts', () {
      final run = _Run.opened('a');
      final led = run.machine.send(
        Observed(const Found(_v2), startedAt: Moment.now()),
      );
      final read = led.whereType<ReadLatest>().single;
      expect(read.at, const Seen('a', _v1));
      expect(run.status, isA<InStep>());

      run.send(LatestRead(read.id, const Seen('b', _v2)));

      expect(run.state.text, 'b');
      expect(run.last<Replaced>().version, _v2);
    });

    test('a version already known is not read', () {
      final run = _Run.opened('a')
        ..send(Observed(const Found(_v1), startedAt: Moment.now()));

      expect(run.all<ReadLatest>(), isEmpty);
    });

    test('a read that finds nothing changes nothing', () {
      final run = _Run.opened('a')..edit('ab', 1);
      run.machine.send(Observed(const Found(_v2), startedAt: Moment.now()));
      run.keep();

      expect(run.status, const Editing(EditPhase.onDevice).matcher);
    });

    test('a read waits for the I/O under way, and reads the newest', () {
      final run = _Run.opened('a')..edit('ab', 1);
      run.machine
        ..send(Observed(const Found(_v2), startedAt: Moment.now()))
        ..send(Observed(const Found(_v3), startedAt: Moment.now()));
      expect(run.all<ReadLatest>(), isEmpty);

      run.machine.send(DraftKept(run.last<KeepDraft>().id, kept: true));
      run.machine.send(
        LatestRead(run.last<ReadLatest>().id, const Seen('y', _v3)),
      );

      expect(run.all<ReadLatest>(), hasLength(1));
      expect((run.status as ChangedElsewhere).theirs.version, _v3);
    });

    test('a version found is read before a move', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..found(const Seen('b', _v2))
        ..edit('a', 2)
        ..send(Move(Ticket()))
        ..keep();
      expect(run.last<Replaced>().text, 'b');
      expect(run.last<MoveFile>().from.version, _v2);
    });

    test('a move waits for a read under way', () {
      final run = _Run.opened('a');
      run.machine.send(Observed(const Found(_v2), startedAt: Moment.now()));
      final read = run.last<ReadLatest>();

      run
        ..send(Move(Ticket()))
        ..send(LatestRead(read.id, const Seen('b', _v2)));

      expect(run.state.text, 'b');
      expect(run.last<MoveFile>().from.version, _v2);
    });

    test('replace the text when there are no edits', () {
      final run = _Run.opened('a')..found(const Seen('x', _v2));
      final replaced = run.last<Replaced>();
      expect((replaced.text, replaced.version, replaced.ackRev), ('x', _v2, 0));
      expect(run.status, isA<InStep>());
    });

    test(
      'are no change when they only restamp or come from before our write',
      () {
        final before = Moment.now();
        final run = _Run.opened('a')
          ..save('ab', 1)
          ..wrote(const Written(Seen('ab', _v2)))
          ..found(const Seen('a', _v1), startedAt: before)
          ..found(const Seen('ab', _v3));
        expect(run.all<Replaced>(), isEmpty);
        expect(run.status, isA<InStep>());
      },
    );

    test(
      'during edits wait for the pick, the edits going on into the draft',
      () {
        final run = _Run.opened('a')
          ..edit('ab', 1)
          ..found(const Seen('x', _v2))
          // Read once the draft is kept.
          ..keep();
        expect(run.status, isA<ChangedElsewhere>());
        run
          ..edit('abc', 2)
          ..keep()
          ..send(const SaveNow());
        expect(run.last<KeepDraft>().text, 'abc');
        expect(run.all<Write>(), isEmpty);
      },
    );

    test('a newer one is what the user picks against', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..found(const Seen('x', _v2))
        ..found(const Seen('y', _v3))
        ..keep()
        ..send(const Pick(PickChoice.mine, seen: _v2, rev: 1));
      expect(run.all<BackUpBoth>(), isEmpty);
      expect((run.status as ChangedElsewhere).theirs.version, _v3);
    });

    test('a file deleted elsewhere keeps the edits until restored', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..send(Observed(const Gone(), startedAt: Moment.now()));
      expect(run.status, isA<DeletedElsewhere>());
      run
        ..keep()
        ..send(const SaveNow());
      expect(run.all<Write>(), isEmpty);
      run.send(const RestoreMine());
      expect(run.last<Restore>().text, 'ab');
      expect(run.last<Restore>().where, const Seen('a', _v1));
      run.wrote(const Written(Seen('ab', _v2)));
      expect(run.status, isA<InStep>());
    });

    test('a restore asked during a keep follows it', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..send(Observed(const Gone(), startedAt: Moment.now()))
        ..send(const RestoreMine());
      expect(run.all<Restore>(), isEmpty);
      run.keep();
      expect(run.last<Restore>().text, 'ab');
    });

    test('a file back as the version edited is written when asked', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..keep()
        ..send(Observed(const Gone(), startedAt: Moment.now()))
        ..found(const Seen('a', _v1));
      expect(run.status, const Editing(EditPhase.onDevice).matcher);
      run.send(const SaveNow());
      expect(run.last<Write>().text, 'ab');
    });

    test('a file changed back to the version edited is written again', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..found(const Seen('x', _v2))
        ..found(const Seen('a', _v1))
        ..keep()
        ..send(const SaveNow());
      expect(run.last<Write>().text, 'ab');
    });

    test('an unknown scan changes nothing', () {
      final run = _Run.opened('a')
        ..send(Observed(const Unknown(), startedAt: Moment.now()));
      expect(run.status, isA<InStep>());
      expect(run.machine.outputs, isEmpty);
    });
  });

  group('picks', () {
    _Run changed() => _Run.opened('a')
      ..edit('ab', 1)
      ..keep()
      ..found(const Seen('x', _v2));

    void backedUp(_Run run, {bool ok = true}) =>
        run.send(BackedUp(run.last<BackUpBoth>().id, ok: ok));

    test('mine writes the edits over theirs, after a backup of both', () {
      final run = changed()
        ..send(const Pick(PickChoice.mine, seen: _v2, rev: 1));
      final backUp = run.last<BackUpBoth>();
      expect((backUp.theirs.text, backUp.mine), ('x', 'ab'));
      backedUp(run);
      expect(run.all<Picked>(), isEmpty);
      final write = run.last<Write>();
      expect(
        (write.text, write.over.version, write.backUpFirst),
        ('ab', _v2, false),
      );
    });

    test('a pick asked during a keep follows it', () {
      final run = changed()
        ..edit('abc', 2)
        ..send(const Pick(PickChoice.mine, seen: _v2, rev: 2));
      expect(run.all<BackUpBoth>(), isEmpty);
      run.keep();
      expect(run.last<BackUpBoth>().mine, 'abc');
    });

    test('theirs shows their text and drops the edits', () {
      final run = changed()
        ..send(const Pick(PickChoice.theirs, seen: _v2, rev: 1));
      backedUp(run);
      expect(run.last<Picked>().text, 'x');
      expect(run.state.text, 'x');
      expect(run.status, isA<InStep>());
    });

    group('after a change elsewhere the editor did not take', () {
      // The editor typed on v1 before the Replaced to v2 reached it.
      _Run ignored() => _Run.opened('a')
        ..found(const Seen('x', _v2))
        ..edit('ab', 1)
        ..edit('abc', 2);

      test('keeps the edits on the device over the version they came from', () {
        final run = ignored();
        expect((run.status as ChangedElsewhere).theirs.version, _v2);
        expect(run.last<KeepDraft>().base, 'a');
      });

      test('mine goes on with typing on the editor\'s version', () {
        final run = ignored()
          ..send(const Pick(PickChoice.mine, seen: _v2, rev: 2))
          ..keep();
        backedUp(run);
        expect(run.all<Picked>(), isEmpty);
        run
          ..keep()
          ..wrote(const Written(Seen('abc', _v3)))
          ..edit('abcd', 3);
        expect(run.status, isA<Editing>());
        expect(run.last<KeepDraft>().base, 'abc');
      });
    });

    test('theirs changes nothing once the edits changed since', () {
      final run = changed()
        ..send(const Pick(PickChoice.theirs, seen: _v2, rev: 1))
        ..edit('abc', 2);
      backedUp(run);
      run.keep();
      expect(run.all<PickNotKept>(), hasLength(1));
      expect(run.state.text, 'abc');
      expect(run.status, isA<ChangedElsewhere>());
    });

    test('change nothing while a newer version waits to be read', () {
      final run = changed()
        ..send(const Pick(PickChoice.mine, seen: _v2, rev: 1));
      run.machine.send(Observed(const Found(_v3), startedAt: Moment.now()));
      backedUp(run);
      expect(run.all<PickNotKept>(), hasLength(1));
    });

    test('change nothing once their version changed again', () {
      final run = changed()
        ..send(const Pick(PickChoice.mine, seen: _v2, rev: 1))
        ..found(const Seen('y', _v3));
      backedUp(run);
      expect(run.all<PickNotKept>(), hasLength(1));
      expect((run.status as ChangedElsewhere).theirs.version, _v3);
    });

    test('without a backup change nothing', () {
      final run = changed()
        ..send(const Pick(PickChoice.mine, seen: _v2, rev: 1));
      backedUp(run, ok: false);
      expect(run.all<PickNotKept>(), hasLength(1));
      expect(run.status, isA<ChangedElsewhere>());
    });

    test('discard does nothing while the edits can still be written', () {
      final run = _Run.opened('a')
        ..save('ab', 1)
        ..wrote(const WriteFailed())
        ..send(const SaveNow())
        ..send(const Discard());
      expect(run.all<Write>(), hasLength(2));
      expect(run.state.text, 'ab');
      expect(run.all<Picked>(), isEmpty);
    });

    test('discard while changed elsewhere takes their version', () {
      final run = changed()..send(const Discard());
      final picked = run.last<Picked>();
      expect((picked.text, picked.version), ('x', _v2));
      expect(run.state.file, _v2);
    });

    test('discard after a delete elsewhere leaves the file deleted', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..keep()
        ..send(Observed(const Gone(), startedAt: Moment.now()))
        ..send(const Discard());
      expect(run.last<Picked>().text, 'a');
      expect(run.status, isA<DeletedElsewhere>());
      expect(run.all<DropDraft>(), hasLength(1));
    });

    test('discard during a keep drops the draft once kept', () {
      final run = changed()
        ..edit('abc', 2)
        ..send(const Discard());
      expect(run.all<DropDraft>(), isEmpty);
      run.keep();
      expect(run.all<DropDraft>(), hasLength(1));
      expect(run.all<KeepDraft>(), hasLength(2));
    });

    test('edits made before a discard is shown are dropped', () {
      final run = changed()..send(const Discard());
      final picked = run.last<Picked>();
      // Typed on the same version before the editor took the pick.
      run.edit('abz', picked.rev + 1, picks: 0);
      expect(run.state.text, 'x');
      expect(run.status, isA<InStep>());
      // The editor goes on from the pick's rev, so a change takes.
      run.found(const Seen('a!', _v3));
      expect(run.last<Replaced>().ackRev, picked.rev);
    });
  });

  group('securing', () {
    test('answers at once when the file holds the edits', () {
      final run = _Run.opened('a')..secure(SecureReason.close);
      expect(run.last<Answer>().kept, isTrue);
      expect(run.status, isA<Closed>());
    });

    test('keeps the edits on the device, then writes them', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..secure(SecureReason.hide);
      expect(run.all<Write>(), isEmpty);
      run.keep();
      expect(run.all<Answer>(), isEmpty);
      run.wrote(const Written(Seen('ab', _v2)));
      expect(run.last<Answer>().kept, isTrue);
      expect(run.status, isA<InStep>());
    });

    test('a second secure is answered with the first', () {
      final run = _Run.opened('a')..save('ab', 1);
      final hide = run.secure(SecureReason.hide);
      final close = run.secure(SecureReason.close);
      expect(run.all<Answer>(), isEmpty);
      run.wrote(const Written(Seen('ab', _v2)));
      expect(
        [for (final answer in run.all<Answer>()) (answer.ticket, answer.kept)],
        [(hide, true), (close, true)],
      );
      expect(run.all<Write>(), hasLength(1));
      expect(run.status, isA<Closed>());
    });

    test('keeps edits that cannot go into the file as a conflict copy', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..keep()
        ..found(const Seen('x', _v2))
        ..secure(SecureReason.close);
      expect(run.last<KeepAsConflict>().text, 'ab');
      expect(run.last<KeepAsConflict>().nextTo.version, _v1);
      expect(run.status, isA<KeptAsConflict>());
      run
        ..edit('abc', 2)
        ..send(ConflictKept(run.last<KeepAsConflict>().id, ok: true));
      expect(run.last<Answer>().kept, isTrue);
      expect(run.state.text, 'ab');
    });

    test('keeps them on the device if no copy can be made', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..keep()
        ..found(const Seen('x', _v2))
        ..secure(SecureReason.close);
      run.send(ConflictKept(run.last<KeepAsConflict>().id, ok: false));
      expect(run.last<Answer>().kept, isFalse);
      expect(run.all<KeepDraft>().single.text, 'ab');
      expect(run.all<DropDraft>(), isEmpty);
      expect(run.status, isA<ChangedElsewhere>());
    });

    test('tries a failed write once more, then keeps a conflict copy', () {
      final run = _Run.opened('a')
        ..save('ab', 1)
        ..wrote(const WriteFailed())
        ..secure(SecureReason.close);
      expect(run.all<Write>(), hasLength(2));
      run.wrote(const WriteFailed());
      expect(run.last<KeepAsConflict>().text, 'ab');
    });

    for (final reason in [SecureReason.hide, SecureReason.exit]) {
      group('on ${reason.name}', () {
        test('keeps edits that cannot go into the file on the device', () {
          final run = _Run.opened('a')
            ..edit('ab', 1)
            ..found(const Seen('x', _v2))
            ..secure(reason);
          expect(run.all<Answer>(), isEmpty);
          run.send(DraftKept(run.last<KeepDraft>().id, kept: true));
          expect(run.last<Answer>().kept, isTrue);
          expect(run.all<KeepAsConflict>(), isEmpty);
          run.edit('abc', 2);
          expect(run.status, isA<ChangedElsewhere>());
          expect(run.state.text, 'abc');
        });

        test('answers at once when the device holds the edits', () {
          final run = _Run.opened('a')
            ..edit('ab', 1)
            ..keep()
            ..send(Observed(const Gone(), startedAt: Moment.now()))
            ..secure(reason);
          expect(run.last<Answer>().kept, isTrue);
          expect(run.all<KeepDraft>(), hasLength(1));
        });

        test('tries a failed write once more, then keeps the edits on '
            'the device', () {
          final run = _Run.opened('a')
            ..save('ab', 1)
            ..wrote(const WriteFailed())
            ..secure(reason)
            ..wrote(const WriteFailed());
          expect(run.all<Write>(), hasLength(2));
          expect(run.all<KeepDraft>(), hasLength(1));
          expect(run.last<Answer>().kept, isTrue);
          expect(run.status, isA<SaveFailed>());
        });

        test('keeps a conflict copy when the device cannot keep them', () {
          final run = _Run.opened('a')
            ..edit('ab', 1)
            ..found(const Seen('x', _v2))
            ..secure(reason);
          run.send(DraftKept(run.last<KeepDraft>().id, kept: false));
          expect(run.last<KeepAsConflict>().text, 'ab');
        });
      });
    }

    test('drops a deleted file\'s draft when there are no edits', () {
      final run = _Run.opened('a')
        ..send(Observed(const Gone(), startedAt: Moment.now()))
        ..secure(SecureReason.close);
      expect(run.last<Answer>().kept, isTrue);
      expect(run.all<KeepAsConflict>(), isEmpty);
    });
  });

  group('a new document', () {
    test('empty is never written', () {
      final run = _Run.unwritten()
        ..edit(' ', 1, lineage: null)
        ..secure(SecureReason.close);
      expect(run.all<Create>(), isEmpty);
      expect(run.last<Answer>().kept, isTrue);
    });

    test('stays on the device until the user leaves it, then is created', () {
      final run = _Run.unwritten()
        ..edit('a', 1, lineage: null)
        ..keep();
      expect(run.last<KeepDraft>().base, isNull);
      run.send(const SaveNow());
      expect(run.all<Create>(), isEmpty);
      run.secure(SecureReason.hide);
      expect(run.last<Create>().text, 'a');
      run.wrote(const Written(Seen('a', _v1)));
      expect(run.last<Answer>().kept, isTrue);
      run.edit('ab', 2, lineage: null);
      expect(run.status, isA<Editing>());
    });

    test('kept on the device when it cannot be created', () {
      final run = _Run.unwritten()
        ..edit('a', 1, lineage: null)
        ..secure(SecureReason.hide)
        ..keep()
        ..wrote(const WriteFailed());
      expect(run.last<Answer>().kept, isTrue);
      expect(run.all<DropDraft>(), isEmpty);
    });

    test('closed, it says it is only on the device', () {
      final run = _Run.unwritten()
        ..edit('a', 1, lineage: null)
        ..secure(SecureReason.close)
        ..keep()
        ..wrote(const WriteFailed());
      expect(run.last<Answer>().kept, isFalse);
      expect(run.all<DropDraft>(), isEmpty);
    });

    test('says it is kept nowhere when neither file nor device take it', () {
      final run = _Run.unwritten()
        ..edit('a', 1, lineage: null)
        ..keep(kept: false)
        ..secure(SecureReason.hide)
        ..wrote(const WriteFailed());
      expect(run.last<Answer>().kept, isFalse);
      expect(run.all<KeepAsConflict>(), isEmpty);
    });

    test('dropped by the user, it is not created when it closes', () {
      final run = _Run.unwritten()
        ..edit('a', 1, lineage: null)
        ..keep()
        ..send(const Discard())
        ..secure(SecureReason.close);
      expect(run.all<Create>(), isEmpty);
      expect(run.state.text, isEmpty);
      expect(run.last<Answer>().kept, isTrue);
    });

    group('created, then changed elsewhere before the editor took it', () {
      /// A new document created as [_v1] holding 'a', then written as
      /// [_v2] elsewhere; the editor typed 'ac' over 'a' before it could
      /// show [_v2], so its lineage is still the new document's.
      _Run changedElsewhere() {
        final run = _Run.unwritten()
          ..edit('a', 1, lineage: null)
          ..keep()
          ..secure(SecureReason.hide)
          ..wrote(const Written(Seen('a', _v1)))
          ..found(const Seen('b', _v2));
        expect(run.last<Replaced>().version, _v2);
        run
          ..edit('ac', 2, lineage: null)
          ..keep();
        expect(run.status, isA<ChangedElsewhere>());
        return run;
      }

      test('the draft builds on the text the edits were made over', () {
        final run = changedElsewhere();
        expect(run.last<KeepDraft>().base, 'a');
      });

      test('seeing the same version again keeps the user\'s pick', () {
        final run = changedElsewhere()
          ..found(const Seen('b', _v2))
          ..send(const SaveNow());
        expect(run.status, isA<ChangedElsewhere>());
        expect(run.all<Write>(), isEmpty, reason: 'b must not be overwritten');
      });

      test('after the user keeps mine, typing on is plain editing', () {
        final run = changedElsewhere()
          ..send(const Pick(PickChoice.mine, seen: _v2, rev: 2));
        run
          ..send(BackedUp(run.last<BackUpBoth>().id, ok: true))
          ..wrote(const Written(Seen('ac', _v3)));
        expect(run.status, isA<InStep>());
        run.edit('acd', 3, lineage: null);
        expect(run.status, isA<Editing>());
      });
    });
  });

  test('a move goes on with the copy', () {
    final run = _Run.opened('a')..move(const Seen('a', _v2));
    expect(run.state.file, _v2);
    run.save('ab', 1);
    expect(run.last<Write>().over.version, _v2);
  });

  test('the state names the file as last read or written', () {
    final run = _Run.opened('a');
    expect(run.state.file, _v1);
    run
      ..save('ab', 1)
      ..wrote(const Written(Seen('ab', _v2)));
    expect(run.state.file, _v2);
    expect(_Run.unwritten().state.file, isNull);
  });

  test('a move that failed changes nothing', () {
    final run = _Run.opened('a')..move(null);
    expect(run.state.file, _v1);
    expect(run.last<MoveAnswer>().started, isTrue);
  });

  test('drafts name the file the edits go over', () {
    final run = _Run.opened('a')..move(const Seen('a', _v2));
    run.edit('ab', 1);
    expect(run.last<KeepDraft>().file, _v2);
    run
      ..keep()
      ..send(const SaveNow())
      ..wrote(const Written(Seen('ab', _v3)));
    expect(run.last<DropDraft>().file, _v3);
  });

  test("a new document's drafts name no file", () {
    final run = _Run.unwritten()..edit('a', 1, lineage: null);
    expect(run.last<KeepDraft>().file, isNull);
    run
      ..keep()
      ..edit('', 2, lineage: null);
    expect(run.last<DropDraft>().file, isNull);
  });
}
