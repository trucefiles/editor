import 'dart:async';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late MemoryFileStore files;
  late FakeLiveChanges live;

  setUp(() {
    files = MemoryFileStore();
    live = FakeLiveChanges();
  });

  /// The hints given while following [selection], as they come.
  List<ChangeHint> follow(
    Selection selection, {
    Duration checkEvery = const Duration(milliseconds: 5),
  }) {
    final hints = <ChangeHint>[];
    final following = BoundedChanges(
      live,
      files,
      selection,
      counts: (file) => file.name.endsWith('.md'),
      checkEvery: () => checkEvery,
    ).changes.listen(hints.add);
    addTearDown(following.cancel);
    return hints;
  }

  /// Lets follows start, hints arrive and checks run.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  test('follows the whole base folder once when all is selected', () async {
    final hints = follow(const WholeFolder());
    await settle();

    live.hint(null, PathChanged(path('a.md')));
    await settle();

    expect(hints, [PathChanged(path('a.md'))]);
    expect(live.followed, [null]);
  });

  test('follows each selected subfolder on its own', () async {
    follow(Selection.of([path('work'), path('home')]));
    await settle();

    expect(live.followed, unorderedEquals([path('work'), path('home')]));
  });

  test('passes on only counted files inside the selection', () async {
    final hints = follow(Selection.of([path('work')]));
    await settle();

    live.hint(path('work'), PathChanged(path('other/a.md')));
    live.hint(path('work'), PathChanged(path('work/notes.txt~')));
    live.hint(path('work'), PathChanged(path('work/a.md')));
    await settle();

    expect(hints, [PathChanged(path('work/a.md'))]);
  });

  test(
    'a gone subfolder lists again and waits; the others stay live',
    () async {
      files.put('home/b.md', 'x');
      final hints = follow(Selection.of([path('work'), path('home')]));
      await settle();

      live.missing.add(path('work'));
      live.end(path('work'));
      await settle();
      live.hint(path('home'), PathChanged(path('home/b.md')));
      await settle();

      expect(hints, [const ListAgain(), PathChanged(path('home/b.md'))]);
      expect(live.follows(path('work')), isFalse);
      expect(live.follows(path('home')), isTrue);
    },
  );

  test('follows a subfolder live again once it is back', () async {
    final hints = follow(Selection.of([path('work')]));
    await settle();
    live.missing.add(path('work'));
    live.end(path('work'));
    await settle();

    live.missing.clear();
    files.put('work/a.md', 'x');
    await settle();
    live.hint(path('work'), PathChanged(path('work/a.md')));
    await settle();

    expect(hints, [
      const ListAgain(),
      const ListAgain(),
      PathChanged(path('work/a.md')),
    ]);
    expect(live.follows(path('work')), isTrue);
  });

  test('a gone base folder is checked once per wait', () async {
    files.failWith = StoreError.notFound;
    follow(
      Selection.of([path('a'), path('b'), path('c')]),
      checkEvery: const Duration(milliseconds: 50),
    );
    await settle();
    final before = files.listCount;
    live.missing.addAll([path('a'), path('b'), path('c')]);
    live
      ..end(path('a'))
      ..end(path('b'))
      ..end(path('c'));

    await Future<void>.delayed(const Duration(milliseconds: 75));

    expect(files.listCount - before, 1);
  });

  test('stops following and checking when cancelled', () async {
    final hints = <ChangeHint>[];
    final following = BoundedChanges(
      live,
      files,
      Selection.of([path('work')]),
      counts: (_) => true,
      checkEvery: () => const Duration(milliseconds: 5),
    ).changes.listen(hints.add);
    await settle();
    live.missing.add(path('work'));
    live.end(path('work'));
    await settle();

    await following.cancel();
    final before = files.listCount;
    await settle();

    expect(files.listCount, before);
    expect(live.follows(path('work')), isFalse);
  });
}
