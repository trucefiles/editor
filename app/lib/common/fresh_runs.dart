/// Runs an async task so that every caller gets the result of a run that
/// started after its call, e.g. a rescan that must see a write just made.
///
/// Runs never overlap: a call during a run waits for one follow-up run,
/// which all calls made during that run share.
final class FreshRuns<T> {
  FreshRuns(this._task);

  final Future<T> Function() _task;
  Future<T>? _running;
  Future<T>? _next;

  Future<T> run() {
    final running = _running;
    if (running == null) return _start();
    return _next ??= running.then<void>((_) {}, onError: (_) {}).then((_) {
      _next = null;
      return _start();
    });
  }

  Future<T> _start() => _running = _task().whenComplete(() => _running = null);
}
