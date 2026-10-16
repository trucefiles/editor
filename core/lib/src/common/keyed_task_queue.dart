import 'package:pool/pool.dart';

/// One queue per key, e.g. per file: tasks for the same key run one at a
/// time, in the order they were added, also after one failed; tasks for
/// different keys run independently. A key's queue is dropped once idle.
final class KeyedTaskQueue<K> {
  final Map<K, _Queue> _queues = {};

  /// Runs [task] after every task added before for [key].
  Future<T> run<T>(K key, Future<T> Function() task) async {
    final queue = _queues.putIfAbsent(key, _Queue.new);
    queue.pending++;
    try {
      return await queue.turns.withResource(task);
    } finally {
      if (--queue.pending == 0) _queues.remove(key);
    }
  }

  /// How many keys have tasks waiting or running.
  int get busyKeys => _queues.length;
}

final class _Queue {
  final turns = Pool(1);
  int pending = 0;
}
