import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

typedef _Run =
    MachineRun<
      CompareMessage<String, String>,
      CompareState<String, String>,
      KeepAnswer,
      CompareEffect<String, String>
    >;

/// A compare machine whose targets are names and sides are texts.
_Run _run({String start = 'a', bool goesOn = true}) =>
    MachineRun.of(compareMachine<String, String>(start, goesOn: goesOn));

extension on _Run {
  /// The load last started ends with [sides].
  void loaded(String sides) =>
      send(SidesLoaded(all<LoadSides<String, String>>().last.id, Ok(sides)));

  void loadFailed() => send(
    SidesLoaded(
      all<LoadSides<String, String>>().last.id,
      const Err(StoreError.ioFailure),
    ),
  );

  Ticket keep() {
    final ticket = Ticket();
    send(Keep(ticket, const KeepOther()));
    return ticket;
  }

  /// The keep last started ends with [outcome]; returns when.
  Moment kept([Result<void, ResolveError> outcome = const Ok(null)]) {
    final endedAt = Moment.now();
    send(
      KeepEnded(
        all<KeepChoice<String, String>>().last.id,
        outcome,
        endedAt: endedAt,
      ),
    );
    return endedAt;
  }

  void scanSeen(String? next) => send(ScanSeen(next, startedAt: Moment.now()));
}

void main() {
  test('loads its first target at once, then shows its sides', () {
    final run = _run();
    expect(run.effects.single, isA<LoadSides<String, String>>());
    expect(run.state, isA<CompareLoading<String, String>>());

    run.loaded('sides of a');
    expect(
      run.state,
      isA<CompareShowing<String, String>>()
          .having((s) => s.target, 'target', 'a')
          .having((s) => s.sides, 'sides', 'sides of a'),
    );
  });

  test('a keep while the sides load is not taken', () {
    final run = _run();
    final ticket = run.keep();
    expect(run.events.single.ticket, ticket);
    expect(run.events.single.taken, isFalse);
    expect(run.all<KeepChoice<String, String>>(), isEmpty);
  });

  test('a second keep while one runs is not taken', () {
    final run = _run()..loaded('x');
    run
      ..keep()
      ..keep();
    expect(run.all<KeepChoice<String, String>>(), hasLength(1));
    expect(run.events.single.taken, isFalse);
  });

  test('after a keep, rescans, then goes on to what a later scan found', () {
    final run = _run()..loaded('x');
    final ticket = run.keep();
    final keep = run.last<KeepChoice<String, String>>();
    expect(keep.target, 'a');
    expect(keep.sides, 'x');

    run.kept();
    expect(
      run.last<CompareEffect<String, String>>(),
      isA<RescanAfterKeep<String, String>>(),
    );
    expect(run.events, isEmpty);

    run.scanSeen('b');
    final answer = run.events.single;
    expect(answer.ticket, ticket);
    expect(answer.taken, isTrue);
    expect(answer.done, isFalse);
    expect(run.last<LoadSides<String, String>>().target, 'b');
  });

  test('a scan that started before the keep ended is not taken', () {
    final run = _run()..loaded('x');
    run.keep();
    final startedEarly = Moment.now();
    run
      ..kept()
      ..send(ScanSeen('b', startedAt: startedEarly));
    expect(run.events, isEmpty);
    expect(run.state, isA<CompareKeeping<String, String>>());
  });

  test('a scan while the keep still runs is not taken', () {
    final run = _run()..loaded('x');
    run
      ..keep()
      ..scanSeen('b');
    expect(run.events, isEmpty);
  });

  test('nothing left: done', () {
    final run = _run()..loaded('x');
    run
      ..keep()
      ..kept()
      ..scanSeen(null);
    expect(run.events.single.done, isTrue);
    expect(
      run.state,
      isA<CompareDone<String, String>>()
          .having((s) => s.target, 'target', 'a')
          .having((s) => s.sides, 'sides', 'x'),
      reason: 'what was kept shows while the screen closes',
    );
  });

  test('a failed keep tells why and shows what is there now', () {
    final run = _run()..loaded('x');
    run
      ..keep()
      ..kept(const Err(ResolveError.changedSinceScan))
      ..scanSeen('a');
    final answer = run.events.single;
    expect(answer.error, ResolveError.changedSinceScan);
    expect(answer.done, isFalse);
    expect(run.last<LoadSides<String, String>>().target, 'a');
  });

  group('without going on (a restore)', () {
    test('a keep that worked ends it', () {
      final run = _run(goesOn: false)..loaded('x');
      run
        ..keep()
        ..kept()
        ..scanSeen('a');
      expect(run.events.single.done, isTrue);
      expect(run.state, isA<CompareDone<String, String>>());
    });

    test('a failed keep loads again', () {
      final run = _run(goesOn: false)..loaded('x');
      run
        ..keep()
        ..kept(const Err(ResolveError.backupFailed))
        ..scanSeen('a');
      expect(run.events.single.done, isFalse);
      expect(run.state, isA<CompareLoading<String, String>>());
    });
  });

  group('after a failed load', () {
    test('the next scan loads what it found', () {
      final run = _run()..loadFailed();
      expect(run.state, isA<CompareLoadFailed<String, String>>());
      run.scanSeen('b');
      expect(run.last<LoadSides<String, String>>().target, 'b');
    });

    test('or the same target, if it found none', () {
      final run = _run()..loadFailed();
      run.scanSeen(null);
      expect(run.last<LoadSides<String, String>>().target, 'a');
    });
  });

  test('a load that is no longer waited for is ignored', () {
    final run = _run()..loadFailed();
    final stale = run.last<LoadSides<String, String>>().id;
    run
      ..scanSeen('b')
      ..send(SidesLoaded(stale, const Ok('stale')))
      ..loaded('sides of b');
    expect(
      run.state,
      isA<CompareShowing<String, String>>().having(
        (s) => s.sides,
        'sides',
        'sides of b',
      ),
    );
  });

  test('keeps its rules and answers every keep once, any order', () {
    for (var seed = 0; seed < 200; seed++) {
      final random = Random(seed);
      final run = _run(goesOn: random.nextBool());
      final asked = <Ticket>{};
      final answered = <Ticket>[];
      final underWay = <CompareEffect<String, String>>[...run.effects];
      for (var step = 0; step < 60; step++) {
        final message = switch (random.nextInt(4)) {
          0 => Keep<String, String>(Ticket(), const KeepCurrent()),
          1 => ScanSeen<String, String>(
            random.nextBool() ? null : 'n$step',
            startedAt: Moment.now(),
          ),
          _ when underWay.isEmpty => ScanSeen<String, String>(
            'n$step',
            startedAt: Moment.now(),
          ),
          _ => switch (underWay.removeAt(random.nextInt(underWay.length))) {
            LoadSides(:final id) => SidesLoaded<String, String>(
              id,
              random.nextBool()
                  ? Ok('s$step')
                  : const Err(StoreError.ioFailure),
            ),
            KeepChoice(:final id) => KeepEnded<String, String>(
              id,
              random.nextBool()
                  ? const Ok(null)
                  : const Err(ResolveError.changedSinceScan),
              endedAt: Moment.now(),
            ),
            RescanAfterKeep<String, String>() => ScanSeen<String, String>(
              'n$step',
              startedAt: Moment.now(),
            ),
          },
        };
        if (message case Keep(:final ticket)) asked.add(ticket);
        for (final output in run.send(message)) {
          switch (output) {
            case final KeepAnswer answer:
              answered.add(answer.ticket);
            case final CompareEffect<String, String> effect:
              underWay.add(effect);
          }
        }
        expect(run.violations, isEmpty, reason: 'seed $seed');
        if (run.state is CompareDone) break;
      }
      expect(answered.toSet().length, answered.length, reason: 'seed $seed');
      expect(asked.containsAll(answered), isTrue, reason: 'seed $seed');
      final waiting = asked.difference(answered.toSet());
      expect(
        waiting.length,
        lessThanOrEqualTo(1),
        reason: 'only the keep under way waits, seed $seed',
      );
      if (waiting.isNotEmpty) {
        expect(run.state, isA<CompareKeeping<String, String>>());
      }
    }
  });
}
