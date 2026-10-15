import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import '../support/memory_file_store.dart';
import '../support/test_helpers.dart';

void main() {
  final at = DateTime.utc(2026, 10, 12, 15);
  final atMicros = at.microsecondsSinceEpoch;

  late MemoryFileStore store;
  late NoteBackups backups;

  setUp(() {
    store = MemoryFileStore();
    backups = NoteBackups(store);
  });

  test('saves a note before editing', () async {
    await backups.saveBeforeEdit(
      at: at,
      notePath: path('lists/todo.md'),
      bytes: bytesOf('before'),
    );

    expect(store.textOf('$atMicros.edit/lists/todo.md'), 'before');
  });

  test('saves both versions', () async {
    await backups.saveBoth(
      at: at,
      notePath: path('lists/todo.md'),
      current: bytesOf('current'),
      other: bytesOf('other'),
    );

    expect(store.textOf('$atMicros.current/lists/todo.md'), 'current');
    expect(store.textOf('$atMicros.other/lists/todo.md'), 'other');
  });

  test('saves only the other version of a deleted note', () async {
    await backups.saveBoth(
      at: at,
      notePath: path('todo.md'),
      current: null,
      other: bytesOf('other'),
    );

    expect(store.files.keys.map((p) => p.value), ['$atMicros.other/todo.md']);
  });

  test('fails if a version cannot be saved', () async {
    store.failWith = StoreError.ioFailure;

    final result = await backups.saveBoth(
      at: at,
      notePath: path('todo.md'),
      current: bytesOf('current'),
      other: bytesOf('other'),
    );

    expect(result.error, StoreError.ioFailure);
  });

  test('lists backups newest first, skipping other files', () async {
    final earlier = at.subtract(const Duration(hours: 1));
    await backups.saveBeforeEdit(
      at: earlier,
      notePath: path('a.md'),
      bytes: bytesOf('a'),
    );
    await backups.saveBeforeEdit(
      at: at,
      notePath: path('b.md'),
      bytes: bytesOf('b'),
    );
    store.put('not-a-backup.txt', 'x');

    final listed = (await backups.list()).value;

    expect(listed.map((b) => (b.notePath, b.savedAt)), [
      (path('b.md'), at),
      (path('a.md'), earlier),
    ]);
    expect(String.fromCharCodes((await backups.read(listed.first)).value), 'b');
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
        notePath: path('todo.md'),
        bytes: bytesOf('before'),
      );
    }
    final oldMicros = old.microsecondsSinceEpoch;
    store
      ..put('not-a-backup.txt', 'kept')
      ..put('$oldMicros.other.todo.md', 'earlier layout');

    await backups.prune(olderThan: at.subtract(const Duration(days: 7)));

    expect(store.files.keys.map((p) => p.value).toSet(), {
      '$atMicros.edit/todo.md',
      'not-a-backup.txt',
    });
  });
}
