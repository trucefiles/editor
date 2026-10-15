import 'dart:async';

import 'package:async/async.dart';
import 'package:test/test.dart';
import 'package:truce_core/testing.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  late MemoryFileStore store;
  late StreamQueue<RelPath> queue;

  const interval = Duration(milliseconds: 10);

  /// Starts polling and waits for the first listing, which is only the
  /// baseline.
  Future<void> start({bool Function(RelPath folder)? enterFolder}) async {
    final changes = PolledFolderChanges(
      store,
      interval: interval,
      enterFolder: enterFolder,
    );
    queue = StreamQueue(changes.changes);
    addTearDown(() => queue.cancel());
    // A queue listens only once asked for an event.
    unawaited(queue.hasNext);
    await _until(() => store.listCount > 0);
  }

  setUp(() => store = MemoryFileStore()..put('a.md', 'a'));

  test('reports created, changed and deleted files', () async {
    await start();

    store.put('b.md', 'b');
    expect(await queue.next, path('b.md'));

    store.put('a.md', 'a2');
    expect(await queue.next, path('a.md'));

    store.files.remove(path('b.md'));
    expect(await queue.next, path('b.md'));
  });

  test('reports nothing while nothing changes', () async {
    await start();
    final listed = store.listCount;
    await _until(() => store.listCount > listed + 2);

    store.put('b.md', 'b');
    expect(await queue.next, path('b.md'));
  });

  test('a folder that is gone counts as empty, until it is back', () async {
    await start();

    store.failWith = StoreError.notFound;
    expect(await queue.next, path('a.md'));

    store.failWith = null;
    expect(await queue.next, path('a.md'));
  });

  test('skips rounds that fail otherwise', () async {
    await start();

    store.failWith = StoreError.ioFailure;
    final listed = store.listCount;
    await _until(() => store.listCount > listed + 2);
    store
      ..failWith = null
      ..put('b.md', 'b');

    expect(await queue.next, path('b.md'));
  });

  test('looks only into the folders it enters', () async {
    await start(enterFolder: (folder) => folder.name != 'skip');

    store
      ..put('skip/x.md', 'x')
      ..put('keep/y.md', 'y');

    expect(await queue.next, path('keep/y.md'));
  });
}

Future<void> _until(bool Function() done) async {
  while (!done()) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
