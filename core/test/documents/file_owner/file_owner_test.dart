import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

const _timing = FileTiming(
  keep: Duration(seconds: 2),
  publish: Duration(minutes: 1),
);

const _v1 = Version(1);
const _v2 = Version(2);
const _v3 = Version(3);

/// A file owner with what it led to so far.
final class _Run {
  _Run(this.owner) {
    owner.outputs.listen(outputs.add);
  }

  _Run.opened(String text)
    : this(openedFileOwner(Seen(text, _v1), timing: _timing));

  _Run.unwritten() : this(newFileOwner(timing: _timing));

  final FileOwner owner;
  final outputs = <FileOutput>[];

  FileStatus get status => owner.state.status;

  T last<T extends FileOutput>() => outputs.whereType<T>().last;

  List<T> all<T extends FileOutput>() => outputs.whereType<T>().toList();

  void send(FileInput input) => owner.send(input);

  /// The editor's text at [rev], on [lineage].
  void edit(String text, int rev, {Version? lineage = _v1}) =>
      send(Edited(text, rev: rev, lineage: lineage));

  void fire(Duration delay) => send(
    TimerFired(
      outputs
          .whereType<StartTimer>()
          .lastWhere((timer) => timer.delay == delay)
          .id,
    ),
  );

  /// The keep timer fires and the draft is kept.
  void keep() {
    fire(_timing.keep);
    send(DraftKept(last<KeepDraft>().id, kept: true));
  }

  void wrote(WriteOutcome outcome) {
    final id = switch (outputs.whereType<FileEffect>().lastWhere(
      (effect) => effect is Write || effect is Create || effect is Restore,
    )) {
      Write(:final id) || Create(:final id) || Restore(:final id) => id,
      _ => throw StateError('no write'),
    };
    send(Wrote(id, outcome, endedAt: Moment.now()));
  }

  void found(Seen seen, {Moment? startedAt}) =>
      send(Observed(Found(seen), startedAt: startedAt ?? Moment.now()));
}

void main() {
  group('saving', () {
    test('keeps edits on the device, then writes them when due', () {
      final run = _Run.opened('a')..edit('ab', 1);
      expect(
        run.status,
        const TypeMatcher<Editing>().having(
          (s) => s.phase,
          'phase',
          EditPhase.typing,
        ),
      );
      run.fire(_timing.keep);
      expect(run.last<KeepDraft>().base, 'a');
      expect(run.last<KeepDraft>().text, 'ab');
      run.send(DraftKept(run.last<KeepDraft>().id, kept: true));
      expect((run.status as Editing).phase, EditPhase.onDevice);
      run.fire(_timing.publish);
      final write = run.last<Write>();
      expect(
        (write.text, write.over.version, write.backUpFirst),
        ('ab', _v1, true),
      );
      run.wrote(const Written(Seen('ab', _v2)));
      expect(run.status, isA<InStep>());
      expect(run.all<DropDraft>(), hasLength(1));
    });

    test('writes edits made during a write after it, without a backup', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..send(const SaveNow())
        ..edit('abc', 2)
        ..wrote(const Written(Seen('ab', _v2)));
      expect(run.status, isA<Editing>());
      run.send(const SaveNow());
      final write = run.last<Write>();
      expect(
        (write.text, write.over.version, write.backUpFirst),
        ('abc', _v2, false),
      );
    });

    test('writes into the file now when the device cannot keep the edits', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..fire(_timing.keep);
      run.send(DraftKept(run.last<KeepDraft>().id, kept: false));
      expect(run.last<Write>().text, 'ab');
    });

    test('a file only restamped at a write is written once more', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..send(const SaveNow())
        ..wrote(const Changed(Seen('a', _v2)));
      expect(run.last<Write>().over.version, _v2);
      run.wrote(const Changed(Seen('a', _v3)));
      expect(run.status, isA<ChangedElsewhere>());
    });

    test('a failed write keeps the edits', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..send(const SaveNow())
        ..wrote(const WriteFailed());
      expect(run.status, isA<SaveFailed>());
      run.keep();
      expect(run.last<KeepDraft>().text, 'ab');
    });
  });

  group('changes elsewhere', () {
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
          ..edit('ab', 1)
          ..send(const SaveNow())
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
          ..found(const Seen('x', _v2));
        expect(run.status, isA<ChangedElsewhere>());
        run
          ..edit('abc', 2)
          ..keep()
          ..fire(_timing.keep);
        expect(run.last<KeepDraft>().text, 'abc');
        expect(run.all<Write>(), isEmpty);
      },
    );

    test('a newer one is what the user picks against', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..found(const Seen('x', _v2))
        ..found(const Seen('y', _v3))
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
      run.wrote(const Written(Seen('ab', _v2)));
      expect(run.status, isA<InStep>());
    });

    test('a file back as the version edited is written again', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..send(Observed(const Gone(), startedAt: Moment.now()))
        ..found(const Seen('a', _v1));
      expect(run.status, isA<Editing>());
    });

    test('a file back as the version edited is written when due', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..keep()
        ..send(Observed(const Gone(), startedAt: Moment.now()))
        ..found(const Seen('a', _v1));
      expect((run.status as Editing).phase, EditPhase.onDevice);
      run.fire(_timing.publish);
      expect(run.last<Write>().text, 'ab');
    });

    test('an unknown scan changes nothing', () {
      final run = _Run.opened('a')
        ..send(Observed(const Unknown(), startedAt: Moment.now()));
      expect(run.status, isA<InStep>());
      expect(run.outputs, isEmpty);
    });
  });

  group('picks', () {
    _Run changed() => _Run.opened('a')
      ..edit('ab', 1)
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

    test('theirs shows their text and drops the edits', () {
      final run = changed()
        ..send(const Pick(PickChoice.theirs, seen: _v2, rev: 1));
      backedUp(run);
      expect(run.last<Picked>().text, 'x');
      expect(run.owner.state.text, 'x');
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
        run.fire(_timing.keep);
        expect(run.last<KeepDraft>().base, 'a');
      });

      test('mine goes on with typing on the editor\'s version', () {
        final run = ignored()
          ..send(const Pick(PickChoice.mine, seen: _v2, rev: 2));
        backedUp(run);
        expect(run.all<Picked>(), isEmpty);
        run
          ..wrote(const Written(Seen('abc', _v3)))
          ..edit('abcd', 3)
          ..fire(_timing.keep);
        expect(run.status, isA<Editing>());
        expect(run.last<KeepDraft>().base, 'abc');
      });
    });

    test('theirs changes nothing once the edits changed since', () {
      final run = changed()
        ..send(const Pick(PickChoice.theirs, seen: _v2, rev: 1))
        ..edit('abc', 2);
      backedUp(run);
      expect(run.all<PickNotKept>(), hasLength(1));
      expect(run.owner.state.text, 'abc');
      expect(run.status, isA<ChangedElsewhere>());
    });

    test('without a backup change nothing', () {
      final run = changed()
        ..send(const Pick(PickChoice.mine, seen: _v2, rev: 1));
      backedUp(run, ok: false);
      expect(run.all<PickNotKept>(), hasLength(1));
      expect(run.status, isA<ChangedElsewhere>());
    });

    test('discard takes the file\'s text', () {
      final run = changed()..send(const Discard());
      expect(run.last<Picked>().text, 'a');
      expect(run.status, isA<InStep>());
    });
  });

  group('securing', () {
    test('answers at once when the file holds the edits', () {
      final run = _Run.opened('a')..send(const Secure(SecureReason.close));
      expect(run.last<Answer>().kept, isTrue);
      expect(run.status, isA<Closed>());
    });

    test('writes the edits first', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..send(const Secure(SecureReason.hide));
      expect(run.all<Answer>(), isEmpty);
      run.wrote(const Written(Seen('ab', _v2)));
      expect(run.last<Answer>().kept, isTrue);
      expect(run.status, isA<InStep>());
    });

    test('keeps edits that cannot go into the file as a conflict copy', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..found(const Seen('x', _v2))
        ..send(const Secure(SecureReason.close));
      expect(run.last<KeepAsConflict>().text, 'ab');
      expect(run.status, isA<KeptAsConflict>());
      run
        ..edit('abc', 2)
        ..send(ConflictKept(run.last<KeepAsConflict>().id, ok: true));
      expect(run.last<Answer>().kept, isTrue);
      expect(run.owner.state.text, 'ab');
    });

    test('keeps them on the device if no copy can be made', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..found(const Seen('x', _v2))
        ..send(const Secure(SecureReason.close));
      run.send(ConflictKept(run.last<KeepAsConflict>().id, ok: false));
      expect(run.last<Answer>().kept, isFalse);
      expect(run.last<KeepDraft>().text, 'ab');
      expect(run.status, isA<ChangedElsewhere>());
    });

    test('tries a failed write once more, then keeps a conflict copy', () {
      final run = _Run.opened('a')
        ..edit('ab', 1)
        ..send(const SaveNow())
        ..wrote(const WriteFailed())
        ..send(const Secure(SecureReason.close));
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
            ..send(Secure(reason));
          expect(run.all<Answer>(), isEmpty);
          run.send(DraftKept(run.last<KeepDraft>().id, kept: true));
          expect(run.last<Answer>().kept, isTrue);
          expect(run.all<KeepAsConflict>(), isEmpty);
          run.edit('abc', 2);
          expect(run.status, isA<ChangedElsewhere>());
          expect(run.owner.state.text, 'abc');
        });

        test('answers at once when the device holds the edits', () {
          final run = _Run.opened('a')
            ..edit('ab', 1)
            ..keep()
            ..send(Observed(const Gone(), startedAt: Moment.now()))
            ..send(Secure(reason));
          expect(run.last<Answer>().kept, isTrue);
          expect(run.all<KeepDraft>(), hasLength(1));
        });

        test('tries a failed write once more, then keeps the edits on '
            'the device', () {
          final run = _Run.opened('a')
            ..edit('ab', 1)
            ..send(const SaveNow())
            ..wrote(const WriteFailed())
            ..send(Secure(reason))
            ..wrote(const WriteFailed());
          run.send(DraftKept(run.last<KeepDraft>().id, kept: true));
          expect(run.last<Answer>().kept, isTrue);
          expect(run.status, isA<SaveFailed>());
        });

        test('keeps a conflict copy when the device cannot keep them', () {
          final run = _Run.opened('a')
            ..edit('ab', 1)
            ..found(const Seen('x', _v2))
            ..send(Secure(reason));
          run.send(DraftKept(run.last<KeepDraft>().id, kept: false));
          expect(run.last<KeepAsConflict>().text, 'ab');
        });
      });
    }

    test('drops a deleted file\'s draft when there are no edits', () {
      final run = _Run.opened('a')
        ..send(Observed(const Gone(), startedAt: Moment.now()))
        ..send(const Secure(SecureReason.close));
      expect(run.last<Answer>().kept, isTrue);
      expect(run.all<KeepAsConflict>(), isEmpty);
    });
  });

  group('a new document', () {
    test('empty is never written', () {
      final run = _Run.unwritten()
        ..edit(' ', 1, lineage: null)
        ..send(const Secure(SecureReason.close));
      expect(run.all<Create>(), isEmpty);
      expect(run.last<Answer>().kept, isTrue);
    });

    test('stays on the device until the user leaves it, then is created', () {
      final run = _Run.unwritten()
        ..edit('a', 1, lineage: null)
        ..keep();
      expect(run.last<KeepDraft>().base, isNull);
      expect(
        run.all<StartTimer>().where((timer) => timer.delay == _timing.publish),
        isEmpty,
      );
      run.send(const Secure(SecureReason.hide));
      expect(run.last<Create>().text, 'a');
      run.wrote(const Written(Seen('a', _v1)));
      expect(run.last<Answer>().kept, isTrue);
      run.edit('ab', 2, lineage: null);
      expect(run.status, isA<Editing>());
    });

    test('kept on the device when it cannot be created', () {
      final run = _Run.unwritten()
        ..edit('a', 1, lineage: null)
        ..send(const Secure(SecureReason.hide))
        ..wrote(const WriteFailed());
      expect(run.last<KeepDraft>().text, 'a');
      run.send(DraftKept(run.last<KeepDraft>().id, kept: true));
      expect(run.last<Answer>().kept, isTrue);
    });

    test('closed, it says it is only on the device', () {
      final run = _Run.unwritten()
        ..edit('a', 1, lineage: null)
        ..send(const Secure(SecureReason.close))
        ..wrote(const WriteFailed());
      expect(run.last<Answer>().kept, isFalse);
      expect(run.last<KeepDraft>().text, 'a');
    });
  });

  test('a move goes on with the copy', () {
    final run = _Run.opened('a')
      ..send(const Moved(Seen('a', _v2)))
      ..edit('ab', 1)
      ..send(const SaveNow());
    expect(run.last<Write>().over.version, _v2);
  });
}
