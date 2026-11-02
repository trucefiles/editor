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

  /// The hints given while following the folder, as they come.
  List<ChangeHint> follow({
    Duration checkEvery = const Duration(milliseconds: 5),
  }) {
    final hints = <ChangeHint>[];
    final following = BoundedChanges(
      live,
      files,
      counts: (file) => file.name.endsWith('.md'),
      checkEvery: () => checkEvery,
    ).changes.listen(hints.add);
    addTearDown(following.cancel);
    return hints;
  }

  /// Lets follows start, hints arrive and checks run.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  test('follows the folder once', () async {
    final hints = follow();
    await settle();

    live.hint(PathChanged(path('a.md')));
    await settle();

    expect(hints, [PathChanged(path('a.md'))]);
    expect(live.followed, 1);
  });

  test('passes on only counted files', () async {
    final hints = follow();
    await settle();

    live
      ..hint(PathChanged(path('work/notes.txt~')))
      ..hint(PathChanged(path('work/a.md')));
    await settle();

    expect(hints, [PathChanged(path('work/a.md'))]);
  });

  test('a gone folder lists again, then is checked once per wait', () async {
    files.failWith = StoreError.notFound;
    final hints = follow(checkEvery: const Duration(milliseconds: 50));
    await settle();
    final before = files.listCount;

    live
      ..missing = true
      ..end();
    await Future<void>.delayed(const Duration(milliseconds: 75));

    expect(hints, [const ListAgain()]);
    expect(live.follows, isFalse);
    expect(files.listCount - before, 1);
  });

  test('follows the folder live again once it is back', () async {
    files.failWith = StoreError.notFound;
    final hints = follow();
    await settle();
    live
      ..missing = true
      ..end();
    await settle();

    live.missing = false;
    files.failWith = null;
    await settle();
    live.hint(PathChanged(path('a.md')));
    await settle();

    expect(hints, [
      const ListAgain(),
      const ListAgain(),
      PathChanged(path('a.md')),
    ]);
    expect(live.follows, isTrue);
  });

  test('a follow that keeps failing while its folder is there tries again '
      'once per wait', () async {
    final hints = follow(checkEvery: const Duration(milliseconds: 20));
    await settle();

    // Watching fails at once each time, the folder stays there.
    live
      ..missing = true
      ..end();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final listings = hints.whereType<ListAgain>();
    // The first follow's end lists once; then each follow started again
    // lists twice: as it starts and as it ends (the last one maybe not
    // yet).
    expect(
      listings.length,
      inInclusiveRange(2 * live.followed - 2, 2 * live.followed - 1),
    );
    expect(live.followed, greaterThan(3));
  });

  test('stops following and checking when cancelled', () async {
    final following = BoundedChanges(
      live,
      files,
      counts: (_) => true,
      checkEvery: () => const Duration(milliseconds: 5),
    ).changes.listen((_) {});
    await settle();
    live
      ..missing = true
      ..end();
    await settle();

    await following.cancel();
    final before = files.listCount;
    await settle();

    expect(files.listCount, before);
    expect(live.follows, isFalse);
  });
}
