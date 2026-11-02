import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late MemoryFileStore files;
  late SpyFileStore spy;
  late BoundedStore store;

  setUp(() {
    files = MemoryFileStore()
      ..put('work/a.md', 'a')
      ..put('work/img.png', 'png')
      ..put('work/deep/b.md', 'b')
      ..put('home/c.md', 'c')
      ..put('top.md', 'top');
    spy = SpyFileStore(files);
    store = BoundedStore(spy, handles: (file) => file.name.endsWith('.md'));
  });

  test('lists only handled files, and every folder', () async {
    final listing = (await store.list()).value;

    expect(
      listing.files.map((file) => file.path.value),
      unorderedEquals(['work/a.md', 'work/deep/b.md', 'home/c.md', 'top.md']),
    );
    expect(
      listing.folders.map((folder) => folder.value),
      unorderedEquals(['work', 'work/deep', 'home']),
    );
    expect(spy.touched, isNot(contains(path('work/img.png'))));
  });

  test('reads any file inside, e.g. a linked image', () async {
    expect(
      (await store.read(path('work/img.png'))).value.bytes,
      bytesOf('png'),
    );
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

  group('createFolder', () {
    test('creates a folder', () async {
      expect(
        await store.createFolder(path('work/2026')),
        isA<Ok<void, StoreError>>(),
      );
      expect(files.emptyFolders, {path('work/2026')});
    });
  });
}
