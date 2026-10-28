import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

typedef _Run = MachineRun<FolderStateMessage, FolderState, Fresh, Object?>;

_Run _run() => MachineRun.of(folderStateMachine());

/// A file listed at [path], in version [version], changed at second
/// [time].
FileEntry _file(String name, {int version = 1, int time = 1}) => FileEntry(
  path(name),
  version: FileVersion(version),
  modified: DateTime.utc(2026, 10, 28, 0, 0, time),
);

FolderScan _scan(
  List<FileEntry> files, {
  List<String> subfolders = const [],
  List<String> unreadable = const [],
  List<Conflict> conflicts = const [],
}) => FolderScan(
  files: files,
  subfolders: subfolders.map(path).toList(),
  conflicts: conflicts,
  unreadable: unreadable.map(path).toList(),
);

Conflict _conflict(String main) => Conflict(
  mainPath: path(main),
  main: null,
  copies: [
    ConflictCopy(
      id: '$main.copy',
      version: const FileVersion(9),
      createdAt: DateTime.utc(2026),
    ),
  ],
);

extension on _Run {
  List<ListBase> get listings => all<ListBase>();
  List<CheckBase> get checks => all<CheckBase>();

  /// The listing last started ends, finding [scan].
  void listed(FolderScan scan, {MarksFiles? marks, Moment? startedAt}) => send(
    ListingDone(
      listings.last.id,
      Ok((scan: scan, marks: marks ?? MarksFiles.none)),
      startedAt: startedAt ?? Moment.now(),
    ),
  );

  void listingFailed(StoreError error) =>
      send(ListingDone(listings.last.id, Err(error), startedAt: Moment.now()));

  /// The check last started ends, finding [part].
  void checked(PartScan part, {MarksFiles? marks, Moment? startedAt}) => send(
    CheckDone(
      checks.last.id,
      Ok(part),
      marks: marks,
      startedAt: startedAt ?? Moment.now(),
    ),
  );

  Ticket refresh() {
    final ticket = Ticket();
    send(Refresh(ticket));
    return ticket;
  }

  List<Ticket> get fresh => [for (final fresh in all<Fresh>()) fresh.ticket];

  /// The wait of [delay] last started is over.
  void waited(Duration delay) =>
      send(all<WaitForChanges>().lastWhere((wait) => wait.delay == delay).done);

  void changed(String base, String name) =>
      send(Hinted(base, PathChanged(path(name))));

  Listed base(String id) => state.bases[id]! as Listed;
}

const _settle = Duration(milliseconds: 500);
const _longest = Duration(seconds: 3);

void main() {
  group('listings', () {
    test('lists nothing before the base folders are known', () {
      final run = _run();
      final ticket = run.refresh();
      expect(run.listings, isEmpty);

      run.send(BasesChanged({'a': 'whole'}));
      expect(run.state.bases['a'], isA<NotListed>());
      expect(run.listings.single.baseId, 'a');
      run.listed(_scan([_file('x.md')]));

      expect(run.base('a').files.keys, [path('x.md')]);
      expect(run.fresh, [ticket]);
    });

    test('lists one base folder at a time; a refresh waits for all', () {
      final run = _run()..send(BasesChanged({'a': 'whole', 'b': 'whole'}));
      expect(run.listings, hasLength(1));
      run.listed(_scan([]));
      final ticket = run.refresh();
      expect(run.listings.map((l) => l.baseId), ['a', 'b']);

      run.listed(_scan([]));
      expect(run.fresh, isEmpty, reason: 'b began before the refresh');
      run.listed(_scan([]));
      expect(run.fresh, isEmpty, reason: 'a is listed again first');
      run.listed(_scan([]));

      expect(run.fresh, [ticket]);
      expect(run.violations, isEmpty);
    });

    test('a refresh during a listing waits for one more, shared', () {
      final run = _run()..send(BasesChanged({'a': 'whole'}));
      final first = run.refresh();
      final second = run.refresh();
      run.listed(_scan([]));
      expect(run.fresh, isEmpty, reason: 'that listing began before them');

      run.listed(_scan([]));

      expect(run.fresh, [first, second]);
      expect(run.listings, hasLength(2));
    });

    test('a failed listing leaves the base folder unknown', () {
      final run = _run()..send(BasesChanged({'a': 'whole'}));
      final ticket = run.refresh();

      run.listingFailed(StoreError.accessDenied);

      expect(run.state.bases['a'], isA<ListingFailed>());
      expect(run.fresh, isEmpty, reason: 'the first listing began before');
      run.listingFailed(StoreError.accessDenied);
      expect(run.fresh, [ticket], reason: 'answered all the same');
    });

    test('holds the conflicts, subfolders and unreadable subfolders', () {
      final run = _run()..send(BasesChanged({'a': 'whole'}));

      run.listed(
        _scan(
          [_file('x.md')],
          subfolders: ['work', 'work/old'],
          unreadable: ['private'],
          conflicts: [_conflict('y.md')],
        ),
      );

      final base = run.base('a');
      expect(base.conflicts.keys, [path('y.md')]);
      expect(base.subfolders, {path('work'), path('work/old')});
      expect(base.sees(path('private/x.md')), isFalse);
      expect(base.sees(path('work/x.md')), isTrue);
    });

    test('asks to read the marks files over the ones known', () {
      final run = _run()..send(BasesChanged({'a': 'whole'}));
      final marks = MarksFiles(const {});
      run
        ..listed(_scan([]), marks: marks)
        ..send(const Hinted('a', ListAgain()));

      expect(run.listings.last.marks, same(marks));
    });
  });

  group('base folders', () {
    test('a new base folder, or one whose selection changed, is listed', () {
      final run = _run()..send(BasesChanged({'a': 'whole'}));
      run.listed(_scan([_file('x.md')]));

      run.send(BasesChanged({'a': 'work', 'b': 'whole'}));
      expect(run.base('a').files.keys, [path('x.md')], reason: 'kept until');
      expect(run.state.bases['b'], isA<NotListed>());

      run.listed(_scan([]));
      run.listed(_scan([]));
      expect(run.listings.map((l) => l.baseId), ['a', 'a', 'b']);
    });

    test('an unchanged base folder is not listed again', () {
      final run = _run()..send(BasesChanged({'a': 'whole'}));
      run
        ..listed(_scan([]))
        ..send(BasesChanged({'a': 'whole'}));

      expect(run.listings, hasLength(1));
    });

    test('one no longer followed goes, and refreshes stop waiting for it', () {
      final run = _run()..send(BasesChanged({'a': 'whole', 'b': 'whole'}));
      run.listed(_scan([]));
      final ticket = run.refresh();
      run.listed(_scan([]));
      run.changed('b', 'x.md');

      run.send(BasesChanged({'a': 'whole'}));
      expect(run.state.bases.keys, ['a']);
      run.listed(_scan([]));

      expect(run.fresh, [ticket]);
      run.waited(_settle);
      expect(run.checks, isEmpty);
      expect(run.violations, isEmpty);
    });

    test('a listing of a base folder that went is dropped', () {
      final run = _run()..send(BasesChanged({'a': 'whole'}));

      run
        ..send(BasesChanged({}))
        ..listed(_scan([_file('x.md')]));

      expect(run.state.bases, isEmpty);
    });
  });

  group('changes', () {
    test('changed paths are checked once changes pause, by folder', () {
      final run = _run()..send(BasesChanged({'a': 'whole'}));
      run
        ..listed(_scan([]))
        ..changed('a', 'work/x.md')
        ..changed('a', 'work/y.md')
        ..changed('a', 'top.md');
      expect(run.checks, isEmpty);

      run.waited(_settle);

      expect(run.checks.single.folders, {path('work'), null});
      expect(run.checks.single.marksFiles, isEmpty);
    });

    test('changes that keep coming are checked after the longest wait', () {
      final run = _run()..send(BasesChanged({'a': 'whole'}));
      run
        ..listed(_scan([]))
        ..changed('a', 'x.md')
        ..changed('a', 'y.md')
        ..waited(_longest);

      expect(run.checks, hasLength(1));
    });

    test('a changed marks file is read again, no folder checked', () {
      final run = _run()..send(BasesChanged({'a': 'whole'}));
      run
        ..listed(_scan([]))
        ..changed('a', 'work/.truce/marks/phone.json')
        ..waited(_settle);

      expect(run.checks.single.folders, isEmpty);
      expect(run.checks.single.marksFiles, {
        path('work/.truce/marks/phone.json'),
      });
    });

    test('list again lists the base folder at once', () {
      final run = _run()..send(BasesChanged({'a': 'whole'}));
      run
        ..listed(_scan([]))
        ..send(const Hinted('a', ListAgain()));

      expect(run.listings, hasLength(2));
    });

    test('hints are ignored while not in use, and dropped when it ends', () {
      final run = _run()..send(BasesChanged({'a': 'whole'}));
      run
        ..listed(_scan([]))
        ..changed('a', 'x.md')
        ..send(const Active(active: false));
      expect(run.violations, isEmpty);
      run
        ..changed('a', 'y.md')
        ..send(const Hinted('a', ListAgain()))
        ..send(const Active(active: true))
        ..waited(_settle);

      expect(run.checks, isEmpty);
      expect(run.listings, hasLength(1));
    });

    test('a whole listing takes the place of the checks due', () {
      final run = _run()..send(BasesChanged({'a': 'whole'}));
      run.changed('a', 'x.md');
      run.waited(_settle);
      run.send(const Hinted('a', ListAgain()));
      expect(run.checks, isEmpty, reason: 'the first listing runs');

      run.listed(_scan([]));
      expect(run.listings, hasLength(2));
      run.listed(_scan([]));

      expect(run.checks, isEmpty);
    });
  });

  group('checks', () {
    late _Run run;

    setUp(() {
      run = _run()..send(BasesChanged({'a': 'whole'}));
      run.listed(
        _scan(
          [_file('work/x.md'), _file('work/deep/y.md'), _file('top.md')],
          subfolders: ['work', 'work/deep', 'other'],
          conflicts: [_conflict('work/x.md'), _conflict('top.md')],
        ),
      );
    });

    test('replace what lies directly in the folders found', () {
      run
        ..changed('a', 'work/x.md')
        ..waited(_settle)
        ..checked(
          PartScan(
            files: [_file('work/z.md', version: 2, time: 5)],
            conflicts: const [],
            found: {path('work')},
            unknown: const {},
          ),
        );

      expect(
        run.base('a').files.keys,
        unorderedEquals([
          path('work/deep/y.md'),
          path('top.md'),
          path('work/z.md'),
        ]),
      );
      expect(run.base('a').conflicts.keys, [path('top.md')]);
    });

    test('drop everything in and below a folder that is gone', () {
      run
        ..changed('a', 'work/x.md')
        ..waited(_settle)
        ..checked(
          const PartScan(files: [], conflicts: [], found: {}, unknown: {}),
        );

      final base = run.base('a');
      expect(base.files.keys, [path('top.md')]);
      expect(base.subfolders, {path('other')});
      expect(base.conflicts.keys, [path('top.md')]);
    });

    test('keep what is in a folder they could not read', () {
      final before = run.base('a').files;
      run
        ..changed('a', 'work/x.md')
        ..waited(_settle)
        ..checked(
          PartScan(
            files: const [],
            conflicts: const [],
            found: const {},
            unknown: {path('work')},
          ),
        );

      expect(run.base('a').files, before);
    });

    test('add a new folder found', () {
      run
        ..changed('a', 'new/x.md')
        ..waited(_settle)
        ..checked(
          PartScan(
            files: [_file('new/x.md')],
            conflicts: const [],
            found: {path('new')},
            unknown: const {},
          ),
        );

      expect(run.base('a').subfolders, contains(path('new')));
      expect(run.base('a').files.keys, contains(path('new/x.md')));
    });

    test('tell when what they saw was seen', () {
      final listedAt = run.base('a').listedAt;
      final checkedAt = Moment.now();
      run
        ..changed('a', 'work/x.md')
        ..waited(_settle)
        ..checked(
          PartScan(
            files: [_file('work/x.md', version: 2)],
            conflicts: const [],
            found: {path('work')},
            unknown: const {},
          ),
          startedAt: checkedAt,
        );

      expect(run.base('a').seenAt(path('work/x.md')), same(checkedAt));
      expect(run.base('a').seenAt(path('work/deep/y.md')), same(checkedAt));
      expect(run.base('a').seenAt(path('top.md')), same(listedAt));
    });

    test('put the marks read again in place', () {
      final marks = MarksFiles(const {});
      run
        ..changed('a', '.truce/marks/phone.json')
        ..waited(_settle)
        ..checked(PartScan.nothing, marks: marks);

      expect(run.base('a').marks, same(marks));
    });

    test('of a base folder whose listing failed wait for a listing', () {
      run
        ..send(const Hinted('a', ListAgain()))
        ..listingFailed(StoreError.ioFailure)
        ..changed('a', 'top.md')
        ..waited(_settle)
        ..checked(
          PartScan(
            files: [_file('top.md')],
            conflicts: const [],
            found: const {null},
            unknown: const {},
          ),
        );

      expect(run.state.bases['a'], isA<ListingFailed>());
    });
  });

  group("the app's own writes", () {
    late _Run run;

    setUp(() {
      run = _run()..send(BasesChanged({'a': 'whole'}));
      run.listed(_scan([_file('x.md', time: 1)]));
    });

    PartScan part(FileEntry file) => PartScan(
      files: [file],
      conflicts: const [],
      found: const {null},
      unknown: const {},
    );

    test('are checked at once', () {
      run.send(AppWrote('a', {path('x.md')}, at: DateTime.utc(2026)));

      expect(run.checks.single.folders, {null});
    });

    test('show their time while a listing shows an older one', () {
      final at = DateTime.utc(2026, 10, 28, 0, 0, 10);
      run
        ..send(AppWrote('a', {path('x.md')}, at: at))
        ..checked(part(_file('x.md', version: 2, time: 3)));

      final shown = run.base('a').files[path('x.md')]!;
      expect(shown.modified, at);
      expect(shown.version, const FileVersion(2));

      run
        ..send(const Hinted('a', ListAgain()))
        ..listed(_scan([_file('x.md', version: 3, time: 4)]));
      expect(run.base('a').files[path('x.md')]!.modified, at);
    });

    test('give way once a later time shows', () {
      final at = DateTime.utc(2026, 10, 28, 0, 0, 10);
      run
        ..send(AppWrote('a', {path('x.md')}, at: at))
        ..checked(part(_file('x.md', version: 2, time: 3)))
        ..send(const Hinted('a', ListAgain()))
        ..listed(_scan([_file('x.md', version: 3, time: 20)]))
        ..send(const Hinted('a', ListAgain()))
        ..listed(_scan([_file('x.md', version: 4, time: 15)]));

      expect(
        run.base('a').files[path('x.md')]!.modified,
        DateTime.utc(2026, 10, 28, 0, 0, 15),
      );
    });

    test('of another base folder are ignored', () {
      run.send(AppWrote('b', {path('x.md')}, at: DateTime.utc(2026)));

      expect(run.checks, isEmpty);
    });
  });

  test('an old result is ignored', () {
    final run = _run()..send(BasesChanged({'a': 'whole'}));
    final old = run.listings.single.id;
    run.listed(_scan([_file('x.md')]));

    run.send(
      ListingDone(
        old,
        Ok((scan: _scan([]), marks: MarksFiles.none)),
        startedAt: Moment.now(),
      ),
    );

    expect(run.base('a').files.keys, [path('x.md')]);
  });
}
