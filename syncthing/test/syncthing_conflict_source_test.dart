import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_syncthing/truce_syncthing.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  const copy1 = 'todo.sync-conflict-20261003-134809-4I343AW.md';

  late MemoryFileStore store;
  late SyncthingConflictSource source;

  setUp(() {
    store = MemoryFileStore();
    source = SyncthingConflictSource(
      store,
      clock: () => DateTime(2026, 10, 13, 14, 30),
    );
  });

  /// The conflicts in [store], as the scan finds them.
  Future<List<Conflict>> scan() async => (await SyncthingFolderScanner(
    store,
    const DefaultFileFilter(SyncthingAdapter(), fakeFileTypes),
  ).scan()).value.conflicts;

  group('read and discard', () {
    late ConflictCopy copy;

    setUp(() async {
      store.put(copy1, 'copy');
      copy = (await scan()).single.copies.single;
    });

    test('read returns the content of an unchanged copy', () async {
      expect(String.fromCharCodes((await source.read(copy)).value), 'copy');
    });

    test('read fails if the copy changed since the scan', () async {
      store.put(copy1, 'changed');

      expect((await source.read(copy)).error, StoreError.changedSinceRead);
    });

    test('discard deletes an unchanged copy', () async {
      await source.discard(copy);

      expect(store.files, isEmpty);
    });

    test('discard keeps a changed copy', () async {
      store.put(copy1, 'changed');

      expect((await source.discard(copy)).error, StoreError.changedSinceRead);
      expect(store.textOf(copy1), 'changed');
    });
  });

  test('reads and discards a copy several levels deep', () async {
    store.put('a/b/c/$copy1', 'deep copy');
    final copy = (await scan()).single.copies.single;

    expect(String.fromCharCodes((await source.read(copy)).value), 'deep copy');
    await source.discard(copy);
    expect(store.files, isEmpty);
  });

  group('add', () {
    test('adds a copy that the scan reports for the main file', () async {
      store.put('a/b/c/todo.md', 'main');

      await source.add(path('a/b/c/todo.md'), bytesOf('mine'));

      final conflict = (await scan()).single;
      expect(conflict.mainPath, path('a/b/c/todo.md'));
      expect(
        conflict.copies.single.id,
        'a/b/c/todo.sync-conflict-20261013-143000.md',
      );
      expect(store.textOf(conflict.copies.single.id), 'mine');
    });

    test('moves on a second if the name is taken', () async {
      await source.add(path('todo.md'), bytesOf('first'));
      await source.add(path('todo.md'), bytesOf('second'));

      expect(store.textOf('todo.sync-conflict-20261013-143001.md'), 'second');
    });
  });
}
