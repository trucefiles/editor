import 'dart:async';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  group('TaskQueue', () {
    test('runs tasks one at a time, in order', () async {
      final queue = TaskQueue();
      final first = Completer<void>();
      final log = <String>[];

      final a = queue.run(() async {
        log.add('a starts');
        await first.future;
        log.add('a ends');
        return 'a';
      });
      final b = queue.run(() async {
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
      final queue = TaskQueue();

      final failed = queue.run<void>(() async => throw StateError('x'));
      final next = queue.run(() async => 'next');

      await expectLater(failed, throwsStateError);
      expect(await next, 'next');
    });

    test('is idle once its tasks ended', () async {
      final queue = TaskQueue();
      expect(queue.isIdle, isTrue);

      final running = queue.run(() async {});
      expect(queue.isIdle, isFalse);
      await running;
      await pumpEventQueue();

      expect(queue.isIdle, isTrue);
    });
  });

  group('KeyedTaskQueue', () {
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

      await queues.run('a', () async {});
      await pumpEventQueue();

      expect(queues.busyKeys, 0);
    });
  });
}
