import 'dart:async';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late MemoryFileStore store;
  late ManualTimers clock;
  late FolderReach reach;
  late List<Reach> seen;

  setUp(() {
    store = MemoryFileStore()..put('a.md', 'a');
    clock = ManualTimers();
    reach = folderReach(store, retries: 2, startTimer: clock.start);
    seen = [];
    reach.changes.listen(seen.add);
  });

  tearDown(() => reach.close());

  void saw(Result<Object?, StoreError> outcome) =>
      reach.send(Accessed(accessOf(outcome)));

  /// Lets every pending check run.
  Future<void> settle() => pumpEventQueue();

  /// Ends the pending wait, then lets the next check run.
  Future<void> tick() async {
    clock.fireAll();
    await settle();
  }

  Future<Reach?> settled() => ask<ReachInput, Settled>(
    reach.send,
    reach.events,
    Settle.new,
  ).then((settled) => settled?.reach);

  test(
    'a failed access to a folder that can be read changes nothing',
    () async {
      saw(const Err(StoreError.notFound));
      await settle();

      expect(reach.state, Reach.reachable);
      expect(seen, isEmpty);
    },
  );

  test('retries a folder that cannot be read, then gives up', () async {
    store.failWith = StoreError.ioFailure;
    saw(const Err(StoreError.ioFailure));
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
    saw(const Err(StoreError.accessDenied));
    await settle();

    store.failWith = null;
    await tick();

    expect(seen, [Reach.retrying, Reach.reachable]);
  });

  test('any access that works ends retrying and unreachable', () async {
    store.failWith = StoreError.notFound;
    saw(const Err(StoreError.notFound));
    await settle();
    saw(const Ok(null));
    expect(reach.state, Reach.reachable);
    await tick();
    expect(reach.state, Reach.reachable);

    saw(const Err(StoreError.notFound));
    await settle();
    await tick();
    await tick();
    expect(reach.state, Reach.unreachable);
    saw(const Ok(null));

    expect(reach.state, Reach.reachable);
  });

  test('failures that say nothing about reach start no check', () async {
    store.failWith = StoreError.ioFailure;
    saw(const Err(StoreError.changedSinceRead));
    saw(const Err(StoreError.alreadyExists));
    await settle();

    expect(reach.state, Reach.reachable);
    expect(store.listCount, 0);
  });

  test('more failures while checking start no second check', () async {
    store.failWith = StoreError.ioFailure;
    saw(const Err(StoreError.ioFailure));
    saw(const Err(StoreError.ioFailure));
    await settle();

    expect(store.listCount, 1);
    expect(clock.pending, hasLength(1));
  });

  test('failures while unreachable start no check', () async {
    store.failWith = StoreError.ioFailure;
    saw(const Err(StoreError.ioFailure));
    await settle();
    await tick();
    await tick();
    final lists = store.listCount;

    saw(const Err(StoreError.ioFailure));
    await settle();

    expect(store.listCount, lists);
  });

  test('a check that hangs counts as failed', () async {
    final hanging = folderReach(
      _HangingStore(),
      retries: 0,
      checkTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(hanging.close);

    hanging.send(const Accessed(Access.mayBeGone));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(hanging.state, Reach.unreachable);
  });

  test('closing ends the retries', () async {
    store.failWith = StoreError.ioFailure;
    saw(const Err(StoreError.ioFailure));
    await settle();

    await reach.close();

    expect(clock.pending, isEmpty);
    expect(seen, [Reach.retrying]);
  });

  test('an access that works during the first check ends it', () async {
    final listing = Completer<void>();
    final slow = folderReach(_SlowStore(listing.future));
    addTearDown(slow.close);

    slow
      ..send(const Accessed(Access.mayBeGone))
      ..send(const Accessed(Access.worked));
    listing.complete();
    await settle();

    expect(slow.state, Reach.reachable);
  });

  test('settled waits for the check and its retries', () async {
    store.failWith = StoreError.ioFailure;
    saw(const Err(StoreError.ioFailure));
    final first = settled();
    await settle();
    await tick();
    await tick();

    expect(await first, Reach.unreachable);
    expect(await settled(), Reach.unreachable);
  });

  test('settled answers between two retries only once they end', () async {
    store.failWith = StoreError.ioFailure;
    saw(const Err(StoreError.ioFailure));
    await settle();
    Reach? answer;
    unawaited(settled().then((reach) => answer = reach));
    await settle();
    expect(answer, isNull);

    store.failWith = null;
    await tick();
    expect(answer, Reach.reachable);
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

/// A store whose listing fails once [listed] completes.
final class _SlowStore implements FileStore {
  _SlowStore(this._listed);

  final Future<void> _listed;

  @override
  Future<Result<Listing, StoreError>> list({
    bool Function(RelPath folder)? enterFolder,
    bool Function(RelPath file)? includeFile,
  }) => _listed.then((_) => const Err(StoreError.ioFailure));

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
