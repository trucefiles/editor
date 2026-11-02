import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late MemoryFileStore files;
  late FakeLiveChanges live;

  setUp(() {
    files = MemoryFileStore()
      ..put('a.md', 'a')
      ..put('b.txt~', 'b');
    live = FakeLiveChanges();
  });

  BoundedPlace bound(LiveChanges? changes) => BoundedPlace(
    files,
    changes,
    handles: (file) => file.name.endsWith('.md'),
    checkEvery: () => const Duration(milliseconds: 5),
  );

  test('files and changes keep to the same handled files', () async {
    final place = bound(live);
    final hints = <ChangeHint>[];
    final following = place.changes!.changes.listen(hints.add);
    addTearDown(following.cancel);
    await Future<void>.delayed(Duration.zero);

    live
      ..hint(PathChanged(path('b.txt~')))
      ..hint(PathChanged(path('a.md')));
    await Future<void>.delayed(Duration.zero);

    expect(
      (await place.files.create(path('c.txt~'), bytesOf('c'))).error,
      StoreError.outside,
    );
    expect((await place.files.list()).value.files.map((file) => file.path), [
      path('a.md'),
    ]);
    expect(hints, [PathChanged(path('a.md'))]);
  });

  test('no changes where the place can not follow them live', () {
    expect(bound(null).changes, isNull);
  });

  test('once closed, refuses everything after the work under way', () async {
    final place = bound(null);
    final reading = place.files.read(path('a.md'));

    final closing = place.close();

    expect(await reading, isA<Ok<FileContent, StoreError>>());
    await closing;
    expect((await place.files.read(path('a.md'))).error, StoreError.closed);
    expect(
      (await place.files.create(path('n.md'), bytesOf('n'))).error,
      StoreError.closed,
    );
  });
}
