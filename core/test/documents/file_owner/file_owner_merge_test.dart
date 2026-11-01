import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

const _v1 = Version(1);
const _v2 = Version(2);
const _v3 = Version(3);

/// A file machine of a type that merges ([FakeTextMerge]), with what it
/// led to so far.
final class _Run {
  _Run(String text)
    : machine = MachineRun.of(
        openedFile(Seen(text, _v1), merge: const FakeTextMerge()),
      );

  final MachineRun<FileMessage, FileState, FileEvent, FileEffect> machine;

  FileState get state => machine.state;
  FileStatus get status => state.status;
  T last<T>() => machine.last<T>();
  List<T> all<T>() => machine.all<T>();

  Seen? _file;

  void send(FileMessage message) {
    for (final read in machine.send(message).whereType<ReadLatest>()) {
      send(LatestRead(read.id, _file));
    }
  }

  void edit(String text, int rev, {Version? lineage = _v1}) =>
      send(Edited(text, rev: rev, lineage: lineage, picks: 0));

  void keep() => send(DraftKept(last<KeepDraft>().id, kept: true));

  void found(Seen seen) {
    _file = seen;
    send(Observed(Found(seen.version), startedAt: Moment.now()));
  }

  void wrote(WriteOutcome outcome) =>
      send(Wrote(last<Write>().id, outcome, endedAt: Moment.now()));
}

void main() {
  group('a change elsewhere meets edits of a type that merges', () {
    test('a version found is merged in, not picked', () {
      final run = _Run('a:1\n')
        ..edit('a:1\nb:1\n', 1)
        ..keep()
        ..found(const Seen('a:2\n', _v2));
      expect(run.status, isA<Editing>());
      expect(run.state.text, 'a:2\nb:1\n');
      final merged = run.last<Merged>();
      expect(
        (merged.text, merged.version, merged.ackRev),
        ('a:2\nb:1\n', _v2, 1),
      );
      expect(merged.lost, isEmpty);
      expect(run.all<BackUpBoth>(), isEmpty, reason: 'no edit lost');
      expect(run.last<KeepDraft>().base, 'a:2\n');
    });

    test('a write answered changed is merged and written again', () {
      final run = _Run('a:1\n')
        ..edit('a:1\nb:1\n', 1)
        ..keep()
        ..send(const SaveNow())
        ..wrote(const Changed(Seen('a:2\n', _v2)));
      expect(run.state.text, 'a:2\nb:1\n');
      run.keep();
      final write = run.last<Write>();
      expect((write.text, write.over.version), ('a:2\nb:1\n', _v2));
      run.wrote(const Written(Seen('a:2\nb:1\n', _v3)));
      expect(run.status, isA<InStep>());
    });

    test('the file that came back after a delete is merged in', () {
      final run = _Run('a:1\n')
        ..edit('a:1\nb:1\n', 1)
        ..keep()
        ..send(Observed(const Gone(), startedAt: Moment.now()));
      expect(run.status, isA<DeletedElsewhere>());
      run.found(const Seen('a:3\n', _v3));
      expect(run.state.text, 'a:3\nb:1\n');
      expect(run.status, isA<Editing>());
    });

    test('edits on a version the editor did not take are merged again', () {
      final run = _Run('a:1\n')
        ..edit('a:1\nb:1\n', 1)
        ..keep()
        ..found(const Seen('a:2\n', _v2))
        // Typed before it took the merge: still on the first version.
        ..edit('a:1\nb:2\n', 2);
      expect(run.state.text, 'a:2\nb:2\n');
      final merged = run.last<Merged>();
      expect((merged.version, merged.ackRev), (_v2, 2));
      expect(run.all<ChangedElsewhere>(), isEmpty);
      // Took it: edits go on normally.
      run.edit('a:2\nb:3\n', 3, lineage: _v2);
      expect(run.state.text, 'a:2\nb:3\n');
      expect(run.all<Merged>(), hasLength(2));
    });

    test('own edits that lose are backed up before any draft', () {
      final run = _Run('a:1\n')
        ..edit('a:1\nb:2\n', 1)
        ..keep()
        // The other device changed b to a newer value.
        ..found(const Seen('a:1\nb:3\n', _v2));
      expect(run.last<Merged>().lost, ['b']);
      final backup = run.last<BackUpBoth>();
      expect((backup.theirs.version, backup.mine), (_v2, 'a:1\nb:2\n'));
      final effects = run.machine.effects;
      expect(effects.last, isA<BackUpBoth>(), reason: 'the next I/O');
      // Merged to theirs: nothing to write, the draft goes after the backup.
      expect(run.status, isA<InStep>());
      run.send(BackedUp(backup.id, ok: false));
      expect(run.machine.effects.last, isA<DropDraft>());
    });

    test('each merge that loses own edits backs them up, in turn', () {
      final run = _Run('a:1\n')
        ..edit('a:1\nb:2\n', 1)
        ..keep()
        ..found(const Seen('a:1\nb:3\n', _v2));
      final first = run.last<BackUpBoth>();
      // Typed twice on the first version while its backup runs: each
      // merge loses b again.
      run
        ..edit('a:1\nb:2\nc:1\n', 2)
        ..edit('a:1\nb:2\nc:2\n', 3);
      expect(run.all<BackUpBoth>(), [first], reason: 'one I/O at a time');

      run.send(BackedUp(first.id, ok: true));
      final second = run.last<BackUpBoth>();
      expect(second.mine, 'a:1\nb:2\nc:1\n');
      run.send(BackedUp(second.id, ok: true));
      expect(run.last<BackUpBoth>().mine, 'a:1\nb:2\nc:2\n');
    });

    test('an edit that only lost against its own base is not named', () {
      final run = _Run('b:1\n')
        ..edit('b:1\nc:1\n', 1)
        ..keep()
        ..found(const Seen('b:2\n', _v2));
      expect(run.last<Merged>().lost, isEmpty);
      expect(run.all<BackUpBoth>(), isEmpty);
    });

    test('texts that cannot merge go to the user, as without a merge', () {
      final run = _Run('a:1\n')
        ..edit('a:1\nb:1\n', 1)
        ..keep()
        ..found(const Seen('not a unit\n', _v2));
      expect(run.status, isA<ChangedElsewhere>());
      expect(run.all<Merged>(), isEmpty);
    });
  });
}
