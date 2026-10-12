import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import '../support/memory_file_store.dart';
import '../support/test_helpers.dart';

void main() {
  const copyName = 'todo.sync-conflict-20261003-134809-4I343AW.md';
  final start = DateTime.utc(2026, 10, 12, 15);

  late MemoryFileStore folder;
  late MemoryFileStore backupStore;
  late DefaultConflictService service;
  late DateTime now;

  setUp(() {
    now = start;
    folder = MemoryFileStore();
    backupStore = MemoryFileStore();
    service = DefaultConflictService(
      folder: folder,
      source: SyncthingConflictSource(
        folder,
        const DefaultFileFilter(
          SyncthingAdapter(),
          ExtensionFileTypeDetector.standard(),
        ),
      ),
      backups: ConflictBackups(backupStore),
      clock: () => now = now.add(const Duration(seconds: 1)),
    );
  });

  Future<Conflict> scanOne() async => (await service.scan()).value.single;

  Future<Result<void, ResolveError>> resolve(
    Conflict conflict,
    Resolution resolution,
  ) => service.resolve(conflict, conflict.copies.first, resolution);

  Set<String> backupTexts() => {
    for (final content in backupStore.files.values)
      String.fromCharCodes(content.bytes),
  };

  group('with a main file', () {
    setUp(() {
      folder
        ..put('todo.md', 'current')
        ..put(copyName, 'other');
    });

    test('KeepCurrent keeps the main file and discards the copy', () async {
      final result = await resolve(await scanOne(), const KeepCurrent());

      expect(result, isA<Ok<void, ResolveError>>());
      expect(folder.textOf('todo.md'), 'current');
      expect(folder.textOf(copyName), isNull);
      expect(backupTexts(), {'current', 'other'});
    });

    test('KeepOther writes the copy to the main file', () async {
      final result = await resolve(await scanOne(), const KeepOther());

      expect(result, isA<Ok<void, ResolveError>>());
      expect(folder.textOf('todo.md'), 'other');
      expect(folder.textOf(copyName), isNull);
      expect(backupTexts(), {'current', 'other'});
    });

    test('fails and changes nothing if the main file changed', () async {
      final conflict = await scanOne();
      folder.put('todo.md', 'edited');

      final result = await resolve(conflict, const KeepOther());

      expect(result.error, ResolveError.changedSinceScan);
      expect(folder.textOf('todo.md'), 'edited');
      expect(folder.textOf(copyName), 'other');
      expect(backupStore.files, isEmpty);
    });

    test('fails and changes nothing if the copy changed', () async {
      final conflict = await scanOne();
      folder.put(copyName, 'edited');

      final result = await resolve(conflict, const KeepCurrent());

      expect(result.error, ResolveError.changedSinceScan);
      expect(folder.textOf(copyName), 'edited');
      expect(backupStore.files, isEmpty);
    });

    test('fails and changes nothing if the backup fails', () async {
      backupStore.failWith = StoreError.ioFailure;

      final result = await resolve(await scanOne(), const KeepOther());

      expect(result.error, ResolveError.backupFailed);
      expect(folder.textOf('todo.md'), 'current');
      expect(folder.textOf(copyName), 'other');
    });

    test('passes access errors on', () async {
      final conflict = await scanOne();
      folder.failWith = StoreError.accessDenied;

      final result = await resolve(conflict, const KeepOther());

      expect(result.error, ResolveError.accessDenied);
    });
  });

  group('orphaned', () {
    setUp(() => folder.put(copyName, 'other'));

    test('KeepCurrent discards the copy', () async {
      final result = await resolve(await scanOne(), const KeepCurrent());

      expect(result, isA<Ok<void, ResolveError>>());
      expect(folder.files, isEmpty);
      expect(backupTexts(), {'other'});
    });

    test('KeepOther restores the copy as the main file', () async {
      final result = await resolve(await scanOne(), const KeepOther());

      expect(result, isA<Ok<void, ResolveError>>());
      expect(folder.textOf('todo.md'), 'other');
      expect(folder.textOf(copyName), isNull);
    });

    test('KeepOther keeps the copy if a main file appeared', () async {
      final conflict = await scanOne();
      folder.put('todo.md', 'new');

      final result = await resolve(conflict, const KeepOther());

      expect(result.error, ResolveError.changedSinceScan);
      expect(folder.textOf('todo.md'), 'new');
      expect(folder.textOf(copyName), 'other');
    });
  });

  test('resolves several copies one by one', () async {
    const newer = 'todo.sync-conflict-20261004-080000-ABCDEFG.md';
    folder
      ..put('todo.md', 'current')
      ..put(copyName, 'first')
      ..put(newer, 'second');

    await resolve(await scanOne(), const KeepOther());
    final next = await scanOne();
    await resolve(next, const KeepCurrent());

    expect(next.copies.map((c) => c.id), [newer]);
    expect(folder.textOf('todo.md'), 'first');
    expect(folder.files.keys.map((p) => p.value), ['todo.md']);
  });

  test('pruneBackups drops old backups', () async {
    folder
      ..put('todo.md', 'current')
      ..put(copyName, 'other');
    await resolve(await scanOne(), const KeepCurrent());

    await service.pruneBackups(olderThan: now.add(const Duration(seconds: 1)));

    expect(backupStore.files, isEmpty);
  });
}
