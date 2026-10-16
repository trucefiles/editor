import 'dart:async';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late MemoryFileStore store;
  late FolderReach reach;
  late List<Reach> seen;

  /// Waits of [FolderReach.retryEvery], ended by [tick].
  late List<Completer<void>> waits;

  setUp(() {
    store = MemoryFileStore()..put('a.md', 'a');
    waits = [];
    reach = FolderReach(
      store,
      retries: 2,
      wait: (_) {
        final wait = Completer<void>();
        waits.add(wait);
        return wait.future;
      },
    );
    seen = [];
    reach.changes.listen(seen.add);
  });

  tearDown(() => reach.dispose());

  /// Lets every pending check and wait run.
  Future<void> settle() => pumpEventQueue();

  /// Ends the pending wait, then lets the next check run.
  Future<void> tick() async {
    waits.removeAt(0).complete();
    await settle();
  }

  test(
    'a failed access to a folder that can be read changes nothing',
    () async {
      reach.saw(const Err(StoreError.notFound));
      await settle();

      expect(reach.state, Reach.reachable);
      expect(seen, isEmpty);
    },
  );

  test('retries a folder that cannot be read, then gives up', () async {
    store.failWith = StoreError.ioFailure;
    reach.saw(const Err(StoreError.ioFailure));
    await settle();
    expect(reach.state, Reach.retrying);

    await tick();
    expect(reach.state, Reach.retrying);
    await tick();

    expect(reach.state, Reach.unreachable);
    expect(seen, [Reach.retrying, Reach.unreachable]);
  });

  test('is reachable again once a retry can read the folder', () async {
    store.failWith = StoreError.accessDenied;
    reach.saw(const Err(StoreError.accessDenied));
    await settle();

    store.failWith = null;
    await tick();

    expect(seen, [Reach.retrying, Reach.reachable]);
  });

  test('any access that works ends retrying and unreachable', () async {
    store.failWith = StoreError.notFound;
    reach.saw(const Err(StoreError.notFound));
    await settle();
    reach.saw(const Ok(null));
    expect(reach.state, Reach.reachable);
    await tick();
    expect(reach.state, Reach.reachable);

    reach.saw(const Err(StoreError.notFound));
    await settle();
    await tick();
    await tick();
    expect(reach.state, Reach.unreachable);
    reach.saw(const Ok(null));

    expect(reach.state, Reach.reachable);
  });

  test('failures that say nothing about reach start no check', () async {
    store.failWith = StoreError.ioFailure;
    reach
      ..saw(const Err(StoreError.changedSinceRead))
      ..saw(const Err(StoreError.alreadyExists));
    await settle();

    expect(reach.state, Reach.reachable);
    expect(store.listCount, 0);
  });

  test('more failures while checking start no second check', () async {
    store.failWith = StoreError.ioFailure;
    reach
      ..saw(const Err(StoreError.ioFailure))
      ..saw(const Err(StoreError.ioFailure));
    await settle();

    expect(store.listCount, 1);
    expect(waits, hasLength(1));
  });

  test('failures while unreachable start no check', () async {
    store.failWith = StoreError.ioFailure;
    reach.saw(const Err(StoreError.ioFailure));
    await settle();
    await tick();
    await tick();
    final lists = store.listCount;

    reach.saw(const Err(StoreError.ioFailure));
    await settle();

    expect(store.listCount, lists);
  });

  test('a check that hangs counts as failed', () async {
    final hanging = FolderReach(
      _HangingStore(),
      retries: 0,
      checkTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(hanging.dispose);

    hanging.saw(const Err(StoreError.ioFailure));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(hanging.state, Reach.unreachable);
  });

  test('a check that ends after dispose tells nothing', () async {
    store.failWith = StoreError.ioFailure;
    reach.saw(const Err(StoreError.ioFailure));
    await settle();
    await reach.dispose();

    await tick();

    expect(seen, [Reach.retrying]);
  });

  test('the reporting store tells how each access went', () async {
    final reported = ReachReportingStore(store, reach);
    store.failWith = StoreError.ioFailure;

    expect((await reported.read(path('a.md'))).error, StoreError.ioFailure);
    await settle();
    expect(reach.state, Reach.retrying);

    store.failWith = null;
    expect(
      await reported.read(path('a.md')),
      isA<Ok<FileContent, StoreError>>(),
    );
    expect(reach.state, Reach.reachable);
  });
}

/// A store whose listing never ends; only listing is used.
final class _HangingStore implements FileStore {
  @override
  Future<Result<Listing, StoreError>> list({
    bool Function(RelPath folder)? enterFolder,
    bool Function(RelPath file)? includeFile,
  }) => Completer<Result<Listing, StoreError>>().future;

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
