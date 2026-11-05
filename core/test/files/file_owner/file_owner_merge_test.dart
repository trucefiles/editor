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

  /// The user picks both merged against [seen], the backup going [ok].
  void pickMerged(Version seen, {required int rev, bool ok = true}) {
    send(Pick(PickChoice.merged, seen: seen, rev: rev));
    send(BackedUp(last<BackUpBoth>().id, ok: ok));
  }
}

void main() {
  group('a change elsewhere meets edits of a type that merges', () {
    test('the user picks, as for any type: nothing merges on its own', () {
      final run = _Run('a:1\n')
        ..edit('a:1\nb:1\n', 1)
        ..keep()
        ..found(const Seen('a:2\n', _v2));
      expect(run.status, isA<ChangedElsewhere>());
      expect(run.state.text, 'a:1\nb:1\n');
      expect(run.all<Picked>(), isEmpty);
    });

    test('both merged: backed up, shown, then written as own edits', () {
      final run = _Run('a:1\n')
        ..edit('a:1\nb:1\n', 1)
        ..keep()
        ..found(const Seen('a:2\n', _v2))
        ..send(const Pick(PickChoice.merged, seen: _v2, rev: 1));
      final backup = run.last<BackUpBoth>();
      expect((backup.theirs.version, backup.mine), (_v2, 'a:1\nb:1\n'));

      run.send(BackedUp(backup.id, ok: true));
      final picked = run.last<Picked>();
      expect((picked.text, picked.version), ('a:2\nb:1\n', _v2));
      expect(run.last<PickMerged>().lost, isEmpty);
      expect(run.status, isA<Editing>());
      run.keep();
      final write = run.last<Write>();
      expect((write.text, write.over.version), ('a:2\nb:1\n', _v2));
      run.wrote(const Written(Seen('a:2\nb:1\n', _v3)));
      expect(run.status, isA<InStep>());
    });

    test('tells whether the two merge when asked, once per question', () {
      bool merges(_Run run, Version seen) {
        final ticket = Ticket();
        run.send(AskMerges(ticket, seen: seen));
        return run
            .all<MergesAnswer>()
            .singleWhere((a) => a.ticket == ticket)
            .merges;
      }

      final merging = _Run('a:1\n')
        ..edit('a:1\nb:1\n', 1)
        ..keep()
        ..found(const Seen('a:2\n', _v2));
      expect(merges(merging, _v2), isTrue);
      expect(
        merges(merging, _v3),
        isFalse,
        reason: 'not the version from elsewhere now',
      );
      final broken = _Run('a:1\n')
        ..edit('a:1\nb:1\n', 1)
        ..keep()
        ..found(const Seen('not a unit\n', _v2));
      expect(merges(broken, _v2), isFalse);
      final inStep = _Run('a:1\n');
      expect(merges(inStep, _v1), isFalse, reason: 'nothing to pick');
    });

    test('merges nothing while no one asks, whatever comes', () {
      final merge = _CountingMerge();
      final run = MachineRun.of(
        openedFile(const Seen('a:1\n', _v1), merge: merge),
      )..send(const Edited('a:1\nb:1\n', rev: 1, lineage: _v1, picks: 0));
      run.send(DraftKept(run.last<KeepDraft>().id, kept: true));
      for (final read
          in run
              .send(Observed(const Found(_v2), startedAt: Moment.now()))
              .whereType<ReadLatest>()) {
        run.send(LatestRead(read.id, const Seen('a:2\n', _v2)));
      }
      expect(run.state.status, isA<ChangedElsewhere>());
      run
        ..send(const Edited('a:1\nb:2\n', rev: 2, lineage: _v1, picks: 0))
        ..send(const SaveNow());

      expect(merge.calls, 0);
    });

    test('both merged into the edits as they are: kept, written over '
        'theirs', () {
      final run = _Run('a:1\n')
        ..edit('a:1\nb:2\n', 1)
        ..keep()
        ..found(const Seen('a:0\n', _v2))
        ..pickMerged(_v2, rev: 1);
      expect(run.all<Picked>(), isEmpty, reason: 'the editor shows it');
      expect(run.last<PickMerged>().lost, ['a'], reason: 'theirs lost');
      expect(run.status, isA<Editing>());
      run.keep();
      final write = run.last<Write>();
      expect((write.text, write.over.version), ('a:1\nb:2\n', _v2));
    });

    test('own edits that lose are named', () {
      final run = _Run('a:1\n')
        ..edit('a:1\nb:2\n', 1)
        ..keep()
        // The other device changed b to a newer value.
        ..found(const Seen('a:1\nb:3\n', _v2))
        ..pickMerged(_v2, rev: 1);
      expect(run.last<PickMerged>().lost, ['b']);
      // Merged to theirs: nothing to write.
      expect(run.state.text, 'a:1\nb:3\n');
      expect(run.status, isA<InStep>());
    });

    test('an edit that only lost against its own base is not named', () {
      final run = _Run('b:1\n')
        ..edit('b:1\nc:1\n', 1)
        ..keep()
        ..found(const Seen('b:2\n', _v2))
        ..pickMerged(_v2, rev: 1);
      expect(run.last<PickMerged>().lost, isEmpty);
      expect(run.state.text, 'b:2\nc:1\n');
    });

    test('no backup, no merge', () {
      final run = _Run('a:1\n')
        ..edit('a:1\nb:1\n', 1)
        ..keep()
        ..found(const Seen('a:2\n', _v2))
        ..pickMerged(_v2, rev: 1, ok: false);
      expect(run.last<PickNotKept>(), isNotNull);
      expect(run.status, isA<ChangedElsewhere>());
      expect(run.state.text, 'a:1\nb:1\n');
    });

    test('edits typed after the pick are not dropped by it', () {
      final run = _Run('a:1\n')
        ..edit('a:1\nb:1\n', 1)
        ..keep()
        ..found(const Seen('a:2\n', _v2))
        ..send(const Pick(PickChoice.merged, seen: _v2, rev: 1))
        ..edit('a:1\nb:2\n', 2);
      run.send(BackedUp(run.last<BackUpBoth>().id, ok: true));
      expect(run.last<PickNotKept>(), isNotNull);
      expect(run.all<PickMerged>(), isEmpty);
      expect(run.state.text, 'a:1\nb:2\n');
    });

    test('texts that cannot merge stay for the user to pick', () {
      final run = _Run('a:1\n')
        ..edit('a:1\nb:1\n', 1)
        ..keep()
        ..found(const Seen('not a unit\n', _v2))
        ..pickMerged(_v2, rev: 1);
      expect(run.last<PickNotKept>(), isNotNull);
      expect(run.status, isA<ChangedElsewhere>());
    });
  });

  test('a type that does not merge never merges a pick', () {
    final run = MachineRun.of(openedFile(const Seen('a:1\n', _v1)));
    run
      ..send(const Edited('a:1\nb:1\n', rev: 1, lineage: _v1, picks: 0))
      ..send(DraftKept(run.last<KeepDraft>().id, kept: true));
    run.send(Observed(const Found(_v2), startedAt: Moment.now()));
    run.send(LatestRead(run.last<ReadLatest>().id, const Seen('a:2\n', _v2)));
    run.send(const Pick(PickChoice.merged, seen: _v2, rev: 1));
    run.send(BackedUp(run.last<BackUpBoth>().id, ok: true));
    expect(run.last<PickNotKept>(), isNotNull);
    expect(run.state.status, isA<ChangedElsewhere>());
  });
}

/// [FakeTextMerge], counting its merges.
final class _CountingMerge implements TextMerge {
  var calls = 0;

  @override
  MergeResult merge(String main, String other, {String? base}) {
    calls++;
    return const FakeTextMerge().merge(main, other, base: base);
  }
}
