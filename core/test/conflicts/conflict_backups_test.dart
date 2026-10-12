import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import '../support/memory_file_store.dart';
import '../support/test_helpers.dart';

void main() {
  final at = DateTime.utc(2026, 10, 12, 15);
  final atMicros = at.microsecondsSinceEpoch;

  late MemoryFileStore store;
  late ConflictBackups backups;

  setUp(() {
    store = MemoryFileStore();
    backups = ConflictBackups(store);
  });

  test('saves both sides under one flat name each', () async {
    await backups.save(
      at: at,
      mainPath: path('lists/todo.md'),
      current: bytesOf('current'),
      other: bytesOf('other'),
    );

    expect(store.textOf('$atMicros.current.lists%2Ftodo.md'), 'current');
    expect(store.textOf('$atMicros.other.lists%2Ftodo.md'), 'other');
  });

  test('saves only the other side of an orphaned conflict', () async {
    await backups.save(
      at: at,
      mainPath: path('todo.md'),
      current: null,
      other: bytesOf('other'),
    );

    expect(store.files.keys.map((p) => p.value), ['$atMicros.other.todo.md']);
  });

  test('fails if a side cannot be saved', () async {
    store.failWith = StoreError.ioFailure;

    final result = await backups.save(
      at: at,
      mainPath: path('todo.md'),
      current: bytesOf('current'),
      other: bytesOf('other'),
    );

    expect(result.error, StoreError.ioFailure);
  });

  test('prune deletes only backups saved before the cut-off', () async {
    final old = at.subtract(const Duration(days: 8));
    for (final savedAt in [old, at]) {
      await backups.save(
        at: savedAt,
        mainPath: path('todo.md'),
        current: null,
        other: bytesOf('other'),
      );
    }
    store.put('not-a-backup.txt', 'kept');

    await backups.prune(olderThan: at.subtract(const Duration(days: 7)));

    expect(store.files.keys.map((p) => p.value).toSet(), {
      '$atMicros.other.todo.md',
      'not-a-backup.txt',
    });
  });
}
