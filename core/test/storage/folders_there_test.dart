import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late MemoryFileStore store;

  setUp(() {
    store = MemoryFileStore()
      ..put('work/a.md', 'a')
      ..put('home/b.md', 'b')
      ..emptyFolders.add(path('work/empty'));
  });

  test('tells which folders are there, walking only the way to them', () async {
    final there = await store.foldersThere({
      path('work/empty'),
      path('gone'),
      path('work/gone'),
    });

    expect(there.value, {path('work/empty')});
    expect(store.lastListed, isEmpty);
  });

  test('counts a folder on an unreadable way as there', () async {
    store.unreadableFolders.add(path('work'));

    expect((await store.foldersThere({path('work/x')})).value, {
      path('work/x'),
    });
  });

  test('fails as the listing does', () async {
    store.failWith = StoreError.notFound;

    expect(
      (await store.foldersThere({path('work')})).error,
      StoreError.notFound,
    );
  });
}
