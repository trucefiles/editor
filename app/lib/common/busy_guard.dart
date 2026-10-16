/// Runs one action at a time and drops calls made while one runs, e.g. a
/// second tap on a button whose first tap is still being handled.
final class BusyGuard {
  bool _busy = false;

  /// Whether an action runs; a UI can show its controls disabled.
  bool get busy => _busy;

  /// Runs [action] unless one runs already; then returns `null` and does
  /// nothing.
  Future<T?> run<T>(Future<T> Function() action) async {
    if (_busy) return null;
    _busy = true;
    try {
      return await action();
    } finally {
      _busy = false;
    }
  }
}
