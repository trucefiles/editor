import 'dart:async';

/// Runs an action once calls to it stop for [settle], but at the latest
/// [maxWait] after the first call, so a steady stream of calls still gets
/// it run now and then.
final class Debouncer {
  Debouncer(this._action, {required this.settle, required this.maxWait});

  final void Function() _action;
  final Duration settle;
  final Duration maxWait;

  Timer? _timer;
  Stopwatch? _sinceFirst;

  void call() {
    _timer?.cancel();
    final sinceFirst = _sinceFirst ??= Stopwatch()..start();
    final left = maxWait - sinceFirst.elapsed;
    _timer = Timer(left < settle ? left : settle, _run);
  }

  /// Drops a pending run.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _sinceFirst = null;
  }

  void _run() {
    cancel();
    _action();
  }
}
