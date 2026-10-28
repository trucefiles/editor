import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late MemoryFileStore inner;
  late List<Set<RelPath>> reported;
  late WriteReportingStore store;

  setUp(() {
    inner = MemoryFileStore();
    reported = [];
    store = WriteReportingStore(inner, reported.add);
  });

  test('tells the paths each write changed', () async {
    final created = (await store.create(path('a.md'), bytesOf('a'))).value;
    final replaced = (await store.replace(
      path('a.md'),
      bytesOf('b'),
      ifUnchanged: created.version,
    )).value;
    final moved = (await store.move(
      path('a.md'),
      path('b.md'),
      ifUnchanged: replaced.version,
    )).value;
    await store.delete(path('b.md'), ifUnchanged: moved.version);

    expect(reported, [
      {path('a.md')},
      {path('a.md')},
      {path('a.md'), path('b.md')},
      {path('b.md')},
    ]);
  });

  test(
    'tells nothing of reads, listings, new folders and failed writes',
    () async {
      inner.put('a.md', 'a');

      await store.read(path('a.md'));
      await store.list();
      await store.create(path('a.md'), bytesOf('x'));
      await store.createFolder(path('new'));

      expect(inner.emptyFolders, {path('new')});
      expect(reported, isEmpty);
    },
  );
}
