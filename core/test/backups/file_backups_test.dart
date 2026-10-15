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

  test('saves a note before editing', () async {
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

  test('saves only the other version of a deleted note', () async {
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
}
