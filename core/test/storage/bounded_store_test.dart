import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late MemoryFileStore files;
  late SpyFileStore spy;
  late BoundedStore store;

  /// Handles `.md` files only.
  BoundedStore bounded(Selection selection) => BoundedStore(
    spy,
    selection,
    handles: (file) => file.name.endsWith('.md'),
  );

  setUp(() {
    files = MemoryFileStore()
      ..put('work/a.md', 'a')
      ..put('work/img.png', 'png')
      ..put('work/deep/b.md', 'b')
      ..put('home/c.md', 'c')
      ..put('top.md', 'top');
    spy = SpyFileStore(files);
    store = bounded(Selection.of([path('work')]));
  });

  test('lists only handled files inside the selection', () async {
    final listing = (await store.list()).value;

    expect(
      listing.files.map((file) => file.path.value),
      unorderedEquals(['work/a.md', 'work/deep/b.md']),
    );
    expect(
      listing.folders.map((folder) => folder.value),
      unorderedEquals(['work', 'work/deep']),
    );
    expect(spy.touched.every(Selection.of([path('work')]).reaches), isTrue);
  });

  test(
    'walks folders on the way to a selected subfolder, lists none',
    () async {
      files.put('home/notes/n.md', 'n');
      final notes = bounded(Selection.of([path('home/notes')]));

      final listing = (await notes.list()).value;

      expect(listing.files.map((file) => file.path.value), ['home/notes/n.md']);
      expect(listing.folders.map((folder) => folder.value), ['home/notes']);
      expect(spy.touched, isNot(contains(path('home/c.md'))));
    },
  );

  test('reads any file inside, e.g. a linked image', () async {
    expect(
      (await store.read(path('work/img.png'))).value.bytes,
      bytesOf('png'),
    );
  });

  test('refuses every access outside as an expected result', () async {
    final version = files.files[path('home/c.md')]!.version;

    expect((await store.read(path('home/c.md'))).error, StoreError.outside);
    expect(
      (await store.create(path('top2.md'), bytesOf('x'))).error,
      StoreError.outside,
    );
    expect(
      (await store.replace(
        path('home/c.md'),
        bytesOf('x'),
        ifUnchanged: version,
      )).error,
      StoreError.outside,
    );
    expect(
      (await store.delete(path('home/c.md'), ifUnchanged: version)).error,
      StoreError.outside,
    );
    expect(spy.touched, isEmpty);
  });

  test('never writes a file it does not handle', () async {
    final version = files.files[path('work/img.png')]!.version;

    expect(
      (await store.create(path('work/new.png'), bytesOf('x'))).error,
      StoreError.outside,
    );
    expect(
      (await store.delete(path('work/img.png'), ifUnchanged: version)).error,
      StoreError.outside,
    );
    expect(files.textOf('work/img.png'), 'png');
  });

  test('moves only from and to handled files inside', () async {
    final version = files.files[path('work/a.md')]!.version;

    expect(
      (await store.move(
        path('work/a.md'),
        path('home/a.md'),
        ifUnchanged: version,
      )).error,
      StoreError.outside,
    );
    expect(
      (await store.move(
        path('work/a.md'),
        path('work/deep/a.md'),
        ifUnchanged: version,
      )).value.path,
      path('work/deep/a.md'),
    );
    expect(files.textOf('work/a.md'), isNull);
  });

  test('never brings back a selected subfolder that is gone', () async {
    files.files.removeWhere((file, _) => file.value.startsWith('work/'));

    expect(
      (await store.create(path('work/new.md'), bytesOf('x'))).error,
      StoreError.notFound,
    );
    expect(files.textOf('work/new.md'), isNull);
  });

  test('creates below a selected subfolder that is there', () async {
    expect(
      (await store.create(path('work/new/x.md'), bytesOf('x'))).value.path,
      path('work/new/x.md'),
    );
  });

  test('nothing selected touches nothing', () async {
    final none = bounded(Selection.nothing);

    expect((await none.list()).value.files, isEmpty);
    expect((await none.read(path('top.md'))).error, StoreError.outside);
  });
}
