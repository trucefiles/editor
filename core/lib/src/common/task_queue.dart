import 'dart:async';

/// Runs async tasks one at a time, in the order they were added; each
/// starts once the one before it ended, also when that one failed.
final class TaskQueue {
  Future<void> _last = Future<void>.value();
  int _pending = 0;

  /// No task is waiting or running.
  bool get isIdle => _pending == 0;

  /// Runs [task] after every task added before; completes with its result.
  Future<T> run<T>(Future<T> Function() task) {
    _pending++;
    final done = _last.then((_) => task());
    _last = done
        .then<void>((_) {}, onError: (_) {})
        .whenComplete(() => _pending--);
    return done;
  }

  /// Completes once the tasks added so far have ended.
  Future<void> get _drained => _last;
}

/// One [TaskQueue] per key, e.g. per file: tasks for the same key run one
/// at a time, tasks for different keys run independently. A key's queue is
/// dropped once idle.
final class KeyedTaskQueue<K> {
  final Map<K, TaskQueue> _queues = {};

  /// Runs [task] after every task added before for [key].
  Future<T> run<T>(K key, Future<T> Function() task) {
    final queue = _queues.putIfAbsent(key, TaskQueue.new);
    final done = queue.run(task);
    unawaited(
      queue._drained.then((_) {
        if (queue.isIdle && identical(_queues[key], queue)) {
          _queues.remove(key);
        }
      }),
    );
    return done;
  }

  /// How many keys have tasks waiting or running.
  int get busyKeys => _queues.length;
}
