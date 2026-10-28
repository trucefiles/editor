import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  const copy1 = 'todo.fake-copy-20261003-134809.md';
  const copy2 = 'todo.fake-copy-20261004-080000.md';

  late MemoryFileStore store;
  late NamedCopiesScanner scanner;

  setUp(() {
    store = MemoryFileStore();
    scanner = NamedCopiesScanner(
      store,
      const DefaultFileFilter(FakeSyncAdapter(), fakeFileTypes),
      const FakeCopyNames(),
    );
  });

  group('files', () {
    test('come with the files asked also, apart from them', () async {
      store
        ..put('todo.md', 'main')
        ..put('.truce/marks/phone.json', '{}')
        ..put('.truce/marks/note.md', 'not shown')
        ..put('lists/.truce/marks/laptop.json', '{}');

      final scan = (await scanner.scan(also: DocumentMarks.files)).value;

      expect(scan.files.map((e) => e.path), [path('todo.md')]);
      expect(scan.subfolders, [path('lists')]);
      expect(
        scan.alsoListed.map((e) => e.path.value),
        unorderedEquals([
          '.truce/marks/phone.json',
          'lists/.truce/marks/laptop.json',
        ]),
      );
      expect(store.listCount, 1);
    });

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
        ..put('.fake/todo.md', 'old');

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
        ..put('a/.fake/b/old.md', 'old')
        ..put('a/b/c/d.md.fake-tmp', 'temp');

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
        ..put('.fake/b/old.md', 'old')
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
        ..put('a/photo.fake-copy-20261003-134809.jpg', 'copy');

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
        ..put('photo.fake-copy-20261003-134809.jpg', 'copy')
        ..put('.fake/$copy1', 'old')
        ..put('.hidden/$copy1', 'copy');

      expect((await scanner.scan()).value.conflicts, isEmpty);
    });
  });

  test('passes storage errors on', () async {
    store.failWith = StoreError.accessDenied;

    expect((await scanner.scan()).error, StoreError.accessDenied);
  });

  group('a part', () {
    test('holds only the files directly in the folders asked, with their '
        'conflicts', () async {
      store
        ..put('top.md', 'top')
        ..put('a/todo.md', 'main')
        ..put('a/$copy1', 'copy')
        ..put('a/deeper/x.md', 'x')
        ..put('b/y.md', 'y');

      final part = (await scanner.scanIn({path('a')})).value;

      expect(part.files.map((f) => f.path), [path('a/todo.md')]);
      expect(part.conflicts.single.copies.single.id, 'a/$copy1');
      expect(part.found, {path('a')});
      expect(part.unknown, isEmpty);
    });

    test('of the top level holds its files only', () async {
      store
        ..put('top.md', 'top')
        ..put('a/todo.md', 'a');

      final part = (await scanner.scanIn({null})).value;

      expect(part.files.map((f) => f.path), [path('top.md')]);
      expect(part.found, {null});
    });

    test('tells folders that are gone from those it cannot read', () async {
      store
        ..put('private/inner/a.md', 'a')
        ..unreadableFolders.add(path('private'));

      final part = (await scanner.scanIn({path('gone'), path('private/inner')}))
          .value;

      expect(part.files, isEmpty);
      expect(part.found, isEmpty);
      expect(part.unknown, {path('private/inner')});
    });

    test('skips filtered folders on the way', () async {
      store.put('.hidden/a.md', 'a');

      final part = (await scanner.scanIn({path('.hidden')})).value;

      expect(part.files, isEmpty);
      expect(part.found, isEmpty);
    });

    test('passes storage errors on', () async {
      store.failWith = StoreError.accessDenied;

      expect(
        (await scanner.scanIn({path('a')})).error,
        StoreError.accessDenied,
      );
    });
  });
}
