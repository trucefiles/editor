import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late MemoryFileStore files;
  late FakeLiveChanges live;

  setUp(() {
    files = MemoryFileStore()
      ..put('work/a.md', 'a')
      ..put('home/b.md', 'b');
    live = FakeLiveChanges();
  });

  BoundedPlace bound(LiveChanges? changes) => BoundedPlace(
    files,
    changes,
    Selection.of([path('work')]),
    handles: (file) => file.name.endsWith('.md'),
    checkEvery: () => const Duration(milliseconds: 5),
  );

  test('files and changes keep to the same selection', () async {
    final place = bound(live);
    final hints = <ChangeHint>[];
    final following = place.changes!.changes.listen(hints.add);
    addTearDown(following.cancel);
    await Future<void>.delayed(Duration.zero);

    live.hint(path('work'), PathChanged(path('home/b.md')));
    live.hint(path('work'), PathChanged(path('work/a.md')));
    await Future<void>.delayed(Duration.zero);

    expect(
      (await place.files.read(path('home/b.md'))).error,
      StoreError.outside,
    );
    expect(
      await place.files.read(path('work/a.md')),
      isA<Ok<FileContent, StoreError>>(),
    );
    expect(hints, [PathChanged(path('work/a.md'))]);
    expect(live.followed, [path('work')]);
  });

  test('no changes where the place can not follow them live', () {
    expect(bound(null).changes, isNull);
  });
}
