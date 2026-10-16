import 'dart:async';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  test('runs the tasks of one key one at a time, in order', () async {
    final queues = KeyedTaskQueue<String>();
    final first = Completer<void>();
    final log = <String>[];

    final a = queues.run('k', () async {
      log.add('a starts');
      await first.future;
      log.add('a ends');
      return 'a';
    });
    final b = queues.run('k', () async {
      log.add('b');
      return 'b';
    });
    await pumpEventQueue();
    expect(log, ['a starts']);

    first.complete();

    expect(await Future.wait([a, b]), ['a', 'b']);
    expect(log, ['a starts', 'a ends', 'b']);
  });

  test('a failed task does not stop the next one', () async {
    final queues = KeyedTaskQueue<String>();

    final failed = queues.run<void>('k', () async => throw StateError('x'));
    final next = queues.run('k', () async => 'next');

    await expectLater(failed, throwsStateError);
    expect(await next, 'next');
  });

  test('tasks of different keys do not wait for each other', () async {
    final queues = KeyedTaskQueue<String>();
    final held = Completer<void>();

    unawaited(queues.run('a', () => held.future));
    final other = await queues.run('b', () async => 'b');

    expect(other, 'b');
    held.complete();
  });

  test('drops the queue of a key once idle', () async {
    final queues = KeyedTaskQueue<String>();
    final held = Completer<void>();

    final running = queues.run('a', () => held.future);
    expect(queues.busyKeys, 1);
    held.complete();
    await running;

    expect(queues.busyKeys, 0);
  });
}
