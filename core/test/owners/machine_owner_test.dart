import 'dart:async';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

// A counter machine: inputs add to the state; `Fetch` starts effects
// whose results add what the handler gives; `Later` waits, then adds 100.

sealed class _Message {
  const _Message();
}

sealed class _In extends _Message {
  const _In();
}

final class _Add extends _In {
  const _Add(this.amount);

  final int amount;
}

final class _Fetch extends _In {
  const _Fetch(this.times);

  /// How many effects to start at once.
  final int times;
}

final class _Later extends _In {
  const _Later();
}

sealed class _Result extends _Message {
  const _Result();
}

final class _Fetched extends _Result {
  const _Fetched(this.amount);

  final int amount;
}

final class _Waited extends _Result {
  const _Waited();
}

final class _Get {
  const _Get(this.index);

  final int index;
}

final class _Sleep implements Wait<_Waited> {
  const _Sleep();

  @override
  EffectId get id => const EffectId(0);

  @override
  Duration get delay => const Duration(seconds: 1);

  @override
  _Waited get done => const _Waited();
}

typedef _Owner = MachineOwner<_Message, _In, _Result, int, int, int, Object>;

final _counter = Machine<_Message, int, int, int, Object>(
  state: 0,
  work: 0,
  step: (state, steps, message) {
    final next = switch (message) {
      _Add(:final amount) || _Fetched(:final amount) => state + amount,
      _Waited() => state + 100,
      _Fetch() || _Later() => state,
    };
    return (
      state: next,
      work: steps + 1,
      events: [next],
      effects: switch (message) {
        _Fetch(:final times) => [for (var i = 0; i < times; i++) _Get(i)],
        _Later() => [const _Sleep()],
        _ => <Object>[],
      },
    );
  },
);

/// As [_counter], but a fetched result also starts a wait.
final _sleepAfterFetch = Machine<_Message, int, int, int, Object>(
  state: 0,
  work: 0,
  step: (state, steps, message) {
    final step = _counter.step(state, steps, message);
    return (
      state: step.state,
      work: step.work,
      events: step.events,
      effects: [...step.effects, if (message is _Fetched) const _Sleep()],
    );
  },
);

/// An answer no input of [_counter] gets.
final class _Answer implements Answering {
  @override
  Ticket get ticket => Ticket();
}

Future<_Result?> _never(Object _) => Completer<_Result?>().future;

void main() {
  test('handles an input before send returns, if none is handled', () {
    final owner = _Owner(_counter)..send(const _Add(2));
    expect(owner.state, 2);
  });

  test('an input sent while one is handled waits for it', () {
    final owner = _Owner(_counter);
    final seen = <int>[];
    owner.events.listen((event) {
      seen.add(event);
      if (event == 1) {
        owner.send(const _Add(10));
        expect(owner.state, 1, reason: 'not handled yet');
      }
    });
    owner.send(const _Add(1));
    expect(seen, [1, 11]);
  });

  test('effects start in order before events fire; events see the state', () {
    final log = <String>[];
    final owner = _Owner(
      _counter,
      handle: (effect) {
        log.add('start ${(effect as _Get).index}');
        return _never(effect);
      },
    )..send(const _Add(3));
    owner.events.listen((event) => log.add('event $event ${owner.state}'));
    owner.send(const _Fetch(2));
    expect(log, ['start 0', 'start 1', 'event 3 3']);
  });

  test('results come back as messages, in the order they end', () async {
    final results = [Completer<_Result?>(), Completer<_Result?>()];
    final owner = _Owner(
      _counter,
      handle: (effect) => results[(effect as _Get).index].future,
    )..send(const _Fetch(2));
    results[1].complete(const _Fetched(5));
    await pumpEventQueue();
    expect(owner.state, 5);
    results[0].complete(null);
    await pumpEventQueue();
    expect(owner.state, 5, reason: 'no result, no step');
  });

  test('starting effects start as the owner is made', () async {
    final owner = _Owner(
      Machine(
        state: _counter.state,
        work: _counter.work,
        effects: const [_Get(0)],
        step: _counter.step,
      ),
      handle: (_) async => const _Fetched(7),
    );
    await pumpEventQueue();
    expect(owner.state, 7);
  });

  test('changes fire only when the state differs', () {
    final owner = _Owner(_counter, handle: _never);
    final changes = <int>[];
    owner.changes.listen(changes.add);
    owner
      ..send(const _Add(1))
      ..send(const _Fetch(1))
      ..send(const _Add(0))
      ..send(const _Add(2));
    expect(changes, [1, 3]);
  });

  test('waits run by the clock given and give their result', () async {
    final clock = ManualTimers();
    final owner = _Owner(_counter, startTimer: clock.start)
      ..send(const _Later());
    expect(clock.pending, [const Duration(seconds: 1)]);
    await pumpEventQueue();
    expect(owner.state, 0);
    clock.fireAll();
    await pumpEventQueue();
    expect(owner.state, 100);
  });

  group('close', () {
    test(
      'drops later inputs; work under way still ends and is handled',
      () async {
        final result = Completer<_Result?>();
        final owner = _Owner(_counter, handle: (_) => result.future)
          ..send(const _Fetch(1));
        final events = <int>[];
        var ended = false;
        owner.events.listen(events.add, onDone: () => ended = true);
        final closed = owner.close();
        owner.send(const _Add(1));
        await pumpEventQueue();
        expect(ended, isFalse);
        result.complete(const _Fetched(7));
        await closed;
        expect(owner.state, 7);
        expect(events, [7]);
        expect(ended, isTrue);
      },
    );

    test('ends waits at once, cancelling their timers', () async {
      final clock = ManualTimers();
      final owner = _Owner(_counter, startTimer: clock.start)
        ..send(const _Later());
      await owner.close();
      expect(clock.pending, isEmpty);
      expect(owner.state, 0);
    });

    test('ends at once when quiet', () async {
      final owner = _Owner(_counter);
      var ended = false;
      owner.changes.listen(null, onDone: () => ended = true);
      await owner.close();
      expect(ended, isTrue);
    });

    test('a failed effect (a bug) is reported and closes it', () async {
      final errors = <Object>[];
      var ended = false;
      await runZonedGuarded(() async {
        final owner = _Owner(_counter, handle: (_) => throw StateError('bug'));
        owner.events.listen(null, onDone: () => ended = true);
        owner.send(const _Fetch(1));
        await pumpEventQueue();
        owner.send(const _Add(1));
        expect(owner.state, 0, reason: 'closed: later inputs are dropped');
      }, (error, _) => errors.add(error));

      expect(errors.single, isA<StateError>());
      expect(ended, isTrue);
    });

    test('a step that throws (a bug) ends it at once', () async {
      final errors = <Object>[];
      Answering? answer;
      var ended = false;
      await runZonedGuarded(() async {
        final owner =
            MachineOwner<_Message, _In, _Result, int, int, int, Object>(
              Machine(
                state: 0,
                work: 0,
                step: (state, work, message) => message is _Later
                    ? throw StateError('bug')
                    : _counter.step(state, work, message),
              ),
            );
        owner.events.listen(null, onDone: () => ended = true);
        owner.send(const _Later());
        owner.send(const _Add(1));
        expect(owner.state, 0, reason: 'ended: later inputs are dropped');
        answer = await ask<_In, _Answer>(
          owner.send,
          owner.events,
          (_) => const _Add(1),
        );
      }, (error, _) => errors.add(error));

      expect(errors.single, isA<StateError>());
      expect(ended, isTrue);
      expect(answer, isNull);
    });

    test('a failed effect ends it while others are under way', () async {
      var ended = false;
      final other = Completer<_Result?>();
      await runZonedGuarded(() async {
        final owner = _Owner(
          _counter,
          handle: (effect) => (effect as _Get).index == 0
              ? other.future
              : Future.error(StateError('bug')),
        );
        owner.events.listen(null, onDone: () => ended = true);
        owner.send(const _Fetch(2));
        await pumpEventQueue();
        expect(ended, isTrue, reason: 'not waiting for the other effect');
        other.complete(const _Fetched(5));
        await pumpEventQueue();
        expect(owner.state, 0, reason: 'its result is ignored');
      }, (_, _) {});
    });

    test('a wait asked after close ends at once', () async {
      final clock = ManualTimers();
      final fetched = Completer<_Result?>();
      final owner = _Owner(
        _sleepAfterFetch,
        handle: (_) => fetched.future,
        startTimer: clock.start,
      )..send(const _Fetch(1));
      final closed = owner.close();
      fetched.complete(const _Fetched(1));
      await closed;
      expect(clock.pending, isEmpty);
    });
  });
}
