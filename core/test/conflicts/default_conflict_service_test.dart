import 'package:test/test.dart';
import 'package:truce_core/testing.dart';
import 'package:truce_core/truce_core.dart';

/// The generic conflict flow on a made-up sync tool; the same flow on
/// Syncthing's real copies is tested in the Syncthing package.
void main() {
  final start = DateTime.utc(2026, 10, 12, 15);

  late MemoryFileStore folder;
  late FakeConflictSource source;
  late MemoryFileStore backupStore;
  late DefaultConflictService service;
  late DateTime now;

  setUp(() {
    now = start;
    folder = MemoryFileStore();
    source = FakeConflictSource();
    backupStore = MemoryFileStore();
    service = DefaultConflictService(
      folder: folder,
      source: source,
      backups: FileBackups(backupStore),
      clock: () => now = now.add(const Duration(seconds: 1)),
    );
  });

  /// The conflict of `todo.md` as a scan would find it now.
  Conflict scan() => source.conflictOf(
    'todo.md',
    main: switch (folder.files[path('todo.md')]) {
      final content? => FileEntry(
        path('todo.md'),
        version: content.version,
        modified: content.modified,
      ),
      null => null,
    },
  );

  Future<Result<void, ResolveError>> resolve(
    Conflict conflict,
    Resolution resolution,
  ) => service.resolve(conflict, conflict.copies.first, resolution);

  Set<String> backupTexts() => {
    for (final content in backupStore.files.values)
      String.fromCharCodes(content.bytes),
  };

  group('with a main file', () {
    late ConflictCopy copy;

    setUp(() {
      folder.put('todo.md', 'current');
      copy = source.put('todo.md', 'other');
    });

    test('KeepCurrent keeps the main file and discards the copy', () async {
      final result = await resolve(scan(), const KeepCurrent());

      expect(result, isA<Ok<void, ResolveError>>());
      expect(folder.textOf('todo.md'), 'current');
      expect(source.copies, isEmpty);
      expect(backupTexts(), {'current', 'other'});
    });

    test('KeepOther writes the copy to the main file', () async {
      final result = await resolve(scan(), const KeepOther());

      expect(result, isA<Ok<void, ResolveError>>());
      expect(folder.textOf('todo.md'), 'other');
      expect(source.copies, isEmpty);
      expect(backupTexts(), {'current', 'other'});
    });

    test('fails and changes nothing if the main file changed', () async {
      final conflict = scan();
      folder.put('todo.md', 'edited');

      final result = await resolve(conflict, const KeepOther());

      expect(result.error, ResolveError.changedSinceScan);
      expect(folder.textOf('todo.md'), 'edited');
      expect(source.textOf(copy), 'other');
      expect(backupStore.files, isEmpty);
    });

    test('fails and changes nothing if the copy changed', () async {
      final conflict = scan();
      source.edit(copy, 'edited');

      final result = await resolve(conflict, const KeepCurrent());

      expect(result.error, ResolveError.changedSinceScan);
      expect(source.textOf(copy), 'edited');
      expect(backupStore.files, isEmpty);
    });

    test('fails and changes nothing if the backup fails', () async {
      backupStore.failWith = StoreError.ioFailure;

      final result = await resolve(scan(), const KeepOther());

      expect(result.error, ResolveError.backupFailed);
      expect(folder.textOf('todo.md'), 'current');
      expect(source.textOf(copy), 'other');
    });

    test('passes access errors on', () async {
      final conflict = scan();
      folder.failWith = StoreError.accessDenied;

      final result = await resolve(conflict, const KeepOther());

      expect(result.error, ResolveError.accessDenied);
    });

    test('keeps the copy if discarding it fails', () async {
      final conflict = scan();
      source.failWith = StoreError.ioFailure;

      final result = await resolve(conflict, const KeepCurrent());

      expect(result.error, ResolveError.ioFailure);
      expect(folder.textOf('todo.md'), 'current');
    });
  });

  group('orphaned', () {
    late ConflictCopy copy;

    setUp(() => copy = source.put('todo.md', 'other'));

    test('KeepCurrent discards the copy', () async {
      final result = await resolve(scan(), const KeepCurrent());

      expect(result, isA<Ok<void, ResolveError>>());
      expect(folder.files, isEmpty);
      expect(source.copies, isEmpty);
      expect(backupTexts(), {'other'});
    });

    test('KeepOther restores the copy as the main file', () async {
      final result = await resolve(scan(), const KeepOther());

      expect(result, isA<Ok<void, ResolveError>>());
      expect(folder.textOf('todo.md'), 'other');
      expect(source.copies, isEmpty);
    });

    test('KeepOther keeps the copy if a main file appeared', () async {
      final conflict = scan();
      folder.put('todo.md', 'new');

      final result = await resolve(conflict, const KeepOther());

      expect(result.error, ResolveError.changedSinceScan);
      expect(folder.textOf('todo.md'), 'new');
      expect(source.textOf(copy), 'other');
    });
  });

  test('resolves several copies one by one, oldest first', () async {
    folder.put('todo.md', 'current');
    source
      ..put('todo.md', 'first')
      ..put('todo.md', 'second');

    await resolve(scan(), const KeepOther());
    await resolve(scan(), const KeepCurrent());

    expect(folder.textOf('todo.md'), 'first');
    expect(source.copies, isEmpty);
  });

  test('readCopy returns the copy as scanned', () async {
    folder.put('todo.md', 'current');
    source.put('todo.md', 'other');

    final copy = scan().copies.single;

    expect(String.fromCharCodes((await service.readCopy(copy)).value), 'other');
  });

  group('readMain', () {
    test('returns the main file as scanned', () async {
      folder.put('todo.md', 'current');
      source.put('todo.md', 'other');

      final main = await service.readMain(scan());

      expect(String.fromCharCodes(main.value), 'current');
    });

    test('fails if the main file changed since the scan', () async {
      folder.put('todo.md', 'current');
      source.put('todo.md', 'other');
      final conflict = scan();
      folder.put('todo.md', 'edited');

      final main = await service.readMain(conflict);

      expect(main.error, StoreError.changedSinceRead);
    });

    test('fails with notFound for an orphaned conflict', () async {
      source.put('todo.md', 'other');

      final main = await service.readMain(scan());

      expect(main.error, StoreError.notFound);
    });
  });

  test('keepAsConflict hands the bytes to the sync tool as a copy', () async {
    folder.put('todo.md', 'current');

    final kept = await service.keepAsConflict(path('todo.md'), bytesOf('mine'));

    expect(kept, isA<Ok<void, StoreError>>());
    expect(folder.textOf('todo.md'), 'current');
    expect(source.textOf(scan().copies.single), 'mine');
  });
}
