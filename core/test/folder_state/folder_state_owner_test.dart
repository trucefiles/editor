import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

/// The folder state owner on the generic scanner and marks of a made-up
/// plugin, over files in memory.
final _a = folderId('a');

void main() {
  late MemoryFileStore store;
  late ManualTimers timers;
  late FolderStateOwner owner;

  setUp(() {
    store = MemoryFileStore()
      ..put('work/plan.md', 'plan')
      ..put('top.md', 'top');
    timers = ManualTimers();
    owner = folderStateOwner(
      (_) => (
        scanner: NamedCopiesScanner(
          store,
          VisibleFileFilter(const FakeSyncRules().isInternal),
          FakeCopyNames(),
        ),
        marks: FileMarks(store, deviceId: 'phone'),
      ),
      startTimer: timers.start,
    );
    addTearDown(owner.close);
  });

  Future<Listed> next() async =>
      (await owner.changes.firstWhere((state) => state.folders[_a] is Listed))
              .folders[_a]!
          as Listed;

  Future<void> refreshed() =>
      ask<FolderStateInput, Fresh>(owner.send, owner.events, Refresh.new);

  test('lists a folder, its marks with it', () async {
    await FileMarks(
      store,
      deviceId: 'laptop',
    ).set(path('top.md'), const FileMark(color: 'teal'));
    store.listCount = 0;
    owner.send(FoldersChanged({_a}));

    final base = await next();

    expect(
      base.found.files.keys,
      unorderedEquals([path('work/plan.md'), path('top.md')]),
    );
    expect(base.found.marks.marks, {
      path('top.md'): const FileMark(color: 'teal'),
    });
    expect(store.listCount, 1, reason: 'one walk for documents and marks');
  });

  test('reads no file to list or check', () async {
    owner.send(FoldersChanged({_a}));
    await next();
    store.put('work/new.md', 'new');
    owner.send(Hinted(_a, PathChanged(path('work/new.md'))));
    await pumpEventQueue();
    timers.fireAll();
    await refreshed();

    expect(store.reads, isEmpty);
  });

  test('a changed path is checked with a listing of its folder only', () async {
    owner.send(FoldersChanged({_a}));
    await next();
    store.put('work/new.md', 'new');

    owner.send(Hinted(_a, PathChanged(path('work/new.md'))));
    await pumpEventQueue();
    timers.fireAll();
    final base = await owner.changes
        .map((state) => state.folders[_a]! as Listed)
        .firstWhere(
          (base) => base.found.files.containsKey(path('work/new.md')),
        );

    expect(store.lastListed, [path('work/plan.md'), path('work/new.md')]);
    expect(base.found.files, hasLength(3));
  });

  test('a refresh lists again and answers once done', () async {
    owner.send(FoldersChanged({_a}));
    await next();
    store.files.remove(path('top.md'));

    await refreshed();

    expect((owner.state.folders[_a]! as Listed).found.files.keys, [
      path('work/plan.md'),
    ]);
  });
}
