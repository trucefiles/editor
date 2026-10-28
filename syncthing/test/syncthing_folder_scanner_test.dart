import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_syncthing/truce_syncthing.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  const copy1 = 'todo.sync-conflict-20261003-134809-4I343AW.md';
  const copy2 = 'todo.sync-conflict-20261004-080000-ABCDEFG.md';

  late MemoryFileStore store;
  late SyncthingFolderScanner scanner;

  setUp(() {
    store = MemoryFileStore();
    scanner = SyncthingFolderScanner(
      store,
      const DefaultFileFilter(SyncthingAdapter(), fakeFileTypes),
    );
  });

  group('files', () {
    test('come with the subfolders that could not be read', () async {
      store
        ..put('todo.md', 'main')
        ..put('private/a.md', 'a')
        ..unreadableFolders.add(path('private'));

      final scan = (await scanner.scan()).value;

      expect(scan.files.map((e) => e.path), [path('todo.md')]);
      expect(scan.unreadable, [path('private')]);
    });

    test('are the included files, without conflict copies', () async {
      store
        ..put('todo.md', 'main')
        ..put('lists/a.md', 'a')
        ..put(copy1, 'copy')
        ..put('photo.jpg', 'jpg')
        ..put('.stversions/todo.md', 'old');

      final files = (await scanner.scan()).value.files;

      expect(
        files.map((f) => f.path.value),
        unorderedEquals(['todo.md', 'lists/a.md']),
      );
    });

    test('include documents several levels deep', () async {
      store
        ..put('a/b/c/d/deep.md', 'deep')
        ..put('a/b/mid.md', 'mid')
        ..put('a/b/.git/objects/x.md', 'hidden')
        ..put('a/.stversions/b/old.md', 'old')
        ..put('a/b/c/.syncthing.d.md.tmp', 'temp');

      final files = (await scanner.scan()).value.files;

      expect(
        files.map((f) => f.path.value),
        unorderedEquals(['a/b/c/d/deep.md', 'a/b/mid.md']),
      );
    });

    test('come with every included subfolder, empty ones too', () async {
      store
        ..put('a/b/c/deep.md', 'deep')
        ..put('a/.git/x.md', 'hidden')
        ..put('.stversions/b/old.md', 'old')
        ..put('photos/cat.jpg', 'jpg')
        ..emptyFolders.add(path('empty/deeper'));

      final subfolders = (await scanner.scan()).value.subfolders;

      expect(
        subfolders.map((f) => f.value),
        unorderedEquals([
          'a',
          'a/b',
          'a/b/c',
          'photos',
          'empty',
          'empty/deeper',
        ]),
      );
    });

    test('are the only files listed, with their conflict copies', () async {
      store
        ..put('a/todo.md', 'main')
        ..put('a/$copy1', 'copy')
        ..put('a/photo.jpg', 'jpg')
        ..put('a/photo.sync-conflict-20261003-134809-4I343AW.jpg', 'copy');

      await scanner.scan();

      expect(
        store.lastListed.map((p) => p.value),
        unorderedEquals(['a/todo.md', 'a/$copy1']),
      );
    });

    test('come from a single listing with the conflicts', () async {
      store
        ..put('todo.md', 'main')
        ..put(copy1, 'copy');

      await scanner.scan();

      expect(store.listCount, 1);
    });
  });

  group('conflicts', () {
    test('groups copies by main file, oldest first', () async {
      final main = store.put('todo.md', 'main');
      store
        ..put(copy2, 'second')
        ..put(copy1, 'first')
        ..put('other.md', 'no conflict');

      final conflict = (await scanner.scan()).value.conflicts.single;

      expect(conflict.mainPath, path('todo.md'));
      expect(conflict.main?.version, main.version);
      expect(conflict.isOrphaned, isFalse);
      expect(conflict.copies.map((c) => c.id), [copy1, copy2]);
      expect(conflict.copies.first.createdAt, DateTime(2026, 10, 3, 13, 48, 9));
    });

    test('finds copies in subfolders, next to their main file', () async {
      store
        ..put('lists/todo.md', 'main')
        ..put('lists/$copy1', 'copy');

      final conflict = (await scanner.scan()).value.conflicts.single;

      expect(conflict.mainPath, path('lists/todo.md'));
      expect(conflict.copies.single.id, 'lists/$copy1');
    });

    test('keeps same-named documents in different subfolders apart', () async {
      store
        ..put('todo.md', 'root')
        ..put('a/todo.md', 'a')
        ..put('a/$copy1', 'a copy')
        ..put('a/b/c/todo.md', 'c')
        ..put('a/b/c/$copy2', 'c copy');

      final conflicts = (await scanner.scan()).value.conflicts;

      expect(
        {
          for (final c in conflicts)
            c.mainPath.value: c.copies.map((copy) => copy.id).toList(),
        },
        {
          'a/todo.md': ['a/$copy1'],
          'a/b/c/todo.md': ['a/b/c/$copy2'],
        },
      );
    });

    test('reports a copy without main file as orphaned', () async {
      store.put(copy1, 'copy');

      final conflict = (await scanner.scan()).value.conflicts.single;

      expect(conflict.mainPath, path('todo.md'));
      expect(conflict.isOrphaned, isTrue);
    });

    test('skips filtered files and folders', () async {
      store
        ..put('photo.sync-conflict-20261003-134809-4I343AW.jpg', 'copy')
        ..put('.stversions/$copy1', 'old')
        ..put('.hidden/$copy1', 'copy');

      expect((await scanner.scan()).value.conflicts, isEmpty);
    });
  });

  test('passes storage errors on', () async {
    store.failWith = StoreError.accessDenied;

    expect((await scanner.scan()).error, StoreError.accessDenied);
  });
}
