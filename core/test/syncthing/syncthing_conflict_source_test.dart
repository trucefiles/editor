import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import '../support/memory_file_store.dart';
import '../support/test_helpers.dart';

void main() {
  const copy1 = 'todo.sync-conflict-20261003-134809-4I343AW.md';
  const copy2 = 'todo.sync-conflict-20261004-080000-ABCDEFG.md';

  late MemoryFileStore store;
  late SyncthingConflictSource source;

  setUp(() {
    store = MemoryFileStore();
    source = SyncthingConflictSource(
      store,
      const DefaultFileFilter(
        SyncthingAdapter(),
        ExtensionFileTypeDetector.standard(),
      ),
    );
  });

  group('find', () {
    test('groups copies by main file, oldest first', () async {
      final mainStamp = store.put('todo.md', 'main');
      store
        ..put(copy2, 'second')
        ..put(copy1, 'first')
        ..put('other.md', 'no conflict');

      final conflict = (await source.find()).value.single;

      expect(conflict.mainPath, path('todo.md'));
      expect(conflict.mainStamp, mainStamp);
      expect(conflict.isOrphaned, isFalse);
      expect(conflict.copies.map((c) => c.id), [copy1, copy2]);
      expect(conflict.copies.first.createdAt, DateTime(2026, 10, 3, 13, 48, 9));
    });

    test('finds copies in subfolders, next to their main file', () async {
      store
        ..put('lists/todo.md', 'main')
        ..put('lists/$copy1', 'copy');

      final conflict = (await source.find()).value.single;

      expect(conflict.mainPath, path('lists/todo.md'));
      expect(conflict.copies.single.id, 'lists/$copy1');
    });

    test('reports a copy without main file as orphaned', () async {
      store.put(copy1, 'copy');

      final conflict = (await source.find()).value.single;

      expect(conflict.mainPath, path('todo.md'));
      expect(conflict.isOrphaned, isTrue);
    });

    test('skips filtered files and folders', () async {
      store
        ..put('photo.sync-conflict-20261003-134809-4I343AW.jpg', 'copy')
        ..put('.stversions/$copy1', 'old')
        ..put('.hidden/$copy1', 'copy');

      expect((await source.find()).value, isEmpty);
    });

    test('passes storage errors on', () async {
      store.failWith = StoreError.accessDenied;

      expect((await source.find()).error, StoreError.accessDenied);
    });
  });

  group('read and discard', () {
    late ConflictCopy copy;

    setUp(() async {
      store.put(copy1, 'copy');
      copy = (await source.find()).value.single.copies.single;
    });

    test('read returns the content of an unchanged copy', () async {
      expect(String.fromCharCodes((await source.read(copy)).value), 'copy');
    });

    test('read fails if the copy changed since find', () async {
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
}
