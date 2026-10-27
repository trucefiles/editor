import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  final at = DateTime.utc(2026, 10, 12, 15);
  final atMicros = at.microsecondsSinceEpoch;

  late MemoryFileStore store;
  late FileBackups backups;

  setUp(() {
    store = MemoryFileStore();
    backups = FileBackups(store);
  });

  test('saves a document before editing', () async {
    await backups.saveBeforeEdit(
      at: at,
      filePath: path('lists/todo.md'),
      bytes: bytesOf('before'),
    );

    expect(store.textOf('$atMicros.edit/lists/todo.md'), 'before');
  });

  test('saves both versions', () async {
    await backups.saveBoth(
      at: at,
      filePath: path('lists/todo.md'),
      current: bytesOf('current'),
      other: bytesOf('other'),
    );

    expect(store.textOf('$atMicros.current/lists/todo.md'), 'current');
    expect(store.textOf('$atMicros.other/lists/todo.md'), 'other');
  });

  test('saves only the other version of a deleted document', () async {
    await backups.saveBoth(
      at: at,
      filePath: path('todo.md'),
      current: null,
      other: bytesOf('other'),
    );

    expect(store.files.keys.map((p) => p.value), ['$atMicros.other/todo.md']);
  });

  test('fails if a version cannot be saved', () async {
    store.failWith = StoreError.ioFailure;

    final result = await backups.saveBoth(
      at: at,
      filePath: path('todo.md'),
      current: bytesOf('current'),
      other: bytesOf('other'),
    );

    expect(result.error, StoreError.ioFailure);
  });

  test('lists backups newest first, skipping other files', () async {
    final earlier = at.subtract(const Duration(hours: 1));
    await backups.saveBeforeEdit(
      at: earlier,
      filePath: path('a.md'),
      bytes: bytesOf('a'),
    );
    await backups.saveBeforeEdit(
      at: at,
      filePath: path('b.md'),
      bytes: bytesOf('b'),
    );
    store.put('not-a-backup.txt', 'x');

    final listed = (await backups.list()).value;

    expect(listed.map((b) => (b.filePath, b.savedAt)), [
      (path('b.md'), at),
      (path('a.md'), earlier),
    ]);
    expect(String.fromCharCodes((await backups.read(listed.first)).value), 'b');
  });

  test('lists no ignored files, e.g. temp files', () async {
    await backups.saveBeforeEdit(
      at: at,
      filePath: path('a.md'),
      bytes: bytesOf('a'),
    );
    store.put('$atMicros.edit/.a.md.tmp', 'cut short');

    final listed = await FileBackups(
      store,
      ignores: (file) => file.name.endsWith('.tmp'),
    ).list();

    expect(listed.value.map((b) => b.filePath), [path('a.md')]);
  });

  test('lists none before the first backup', () async {
    store.failWith = StoreError.notFound;

    expect((await backups.list()).value, isEmpty);
  });

  test('prune deletes only backups saved before the cut-off', () async {
    final old = at.subtract(const Duration(days: 8));
    for (final savedAt in [old, at]) {
      await backups.saveBeforeEdit(
        at: savedAt,
        filePath: path('todo.md'),
        bytes: bytesOf('before'),
      );
    }
    store.put('not-a-backup.txt', 'kept');

    await backups.prune(olderThan: at.subtract(const Duration(days: 7)));

    expect(store.files.keys.map((p) => p.value).toSet(), {
      '$atMicros.edit/todo.md',
      'not-a-backup.txt',
    });
  });

  test('keeps two backups of one file and kind saved in the same µs', () async {
    for (final text in ['first', 'second']) {
      await backups.saveBeforeEdit(
        at: at,
        filePath: path('todo.md'),
        bytes: bytesOf(text),
      );
    }

    expect(store.textOf('$atMicros.edit/todo.md'), 'first');
    expect(store.textOf('${atMicros + 1}.edit/todo.md'), 'second');
  });

  test('lists the backups of one file', () async {
    await backups.saveBeforeEdit(
      at: at,
      filePath: path('a.md'),
      bytes: bytesOf('a'),
    );
    await backups.saveBeforeEdit(
      at: at,
      filePath: path('b.md'),
      bytes: bytesOf('b'),
    );

    final listed = (await backups.listOf(path('a.md'))).value;

    expect(listed.map((b) => b.filePath), [path('a.md')]);
  });

  test('deletes one backup', () async {
    await backups.saveBoth(
      at: at,
      filePath: path('todo.md'),
      current: bytesOf('current'),
      other: bytesOf('other'),
    );
    final other = (await backups.list()).value.firstWhere(
      (b) => b.kind == BackupKind.other,
    );

    await backups.delete(other);

    expect(store.files.keys.map((p) => p.value), ['$atMicros.current/todo.md']);
  });

  group('moveAll', () {
    test(
      'moves a file\'s backups to its new path, keeping time and kind',
      () async {
        await backups.saveBoth(
          at: at,
          filePath: path('old.md'),
          current: bytesOf('current'),
          other: bytesOf('other'),
        );
        await backups.saveBeforeEdit(
          at: at,
          filePath: path('else.md'),
          bytes: bytesOf('else'),
        );

        await backups.moveAll(
          from: path('old.md'),
          to: path('sub/new.md'),
          into: backups,
        );

        expect(store.files.keys.map((p) => p.value).toSet(), {
          '$atMicros.current/sub/new.md',
          '$atMicros.other/sub/new.md',
          '$atMicros.edit/else.md',
        });
        expect(store.textOf('$atMicros.other/sub/new.md'), 'other');
      },
    );

    test('moves them into another folder\'s backups', () async {
      final otherStore = MemoryFileStore();
      await backups.saveBeforeEdit(
        at: at,
        filePath: path('old.md'),
        bytes: bytesOf('before'),
      );

      await backups.moveAll(
        from: path('old.md'),
        to: path('new.md'),
        into: FileBackups(otherStore),
      );

      expect(store.files, isEmpty);
      expect(otherStore.textOf('$atMicros.edit/new.md'), 'before');
    });

    test('keeps a backup here if it cannot be saved there', () async {
      final otherStore = MemoryFileStore()..failWith = StoreError.ioFailure;
      await backups.saveBeforeEdit(
        at: at,
        filePath: path('old.md'),
        bytes: bytesOf('before'),
      );

      final moved = await backups.moveAll(
        from: path('old.md'),
        to: path('new.md'),
        into: FileBackups(otherStore),
      );

      expect(moved.error, StoreError.ioFailure);
      expect(store.textOf('$atMicros.edit/old.md'), 'before');
    });
  });
}
