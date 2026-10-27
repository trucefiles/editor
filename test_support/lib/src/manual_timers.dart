import 'dart:async';

/// Timers that fire only when a test says ([fire]); hand [start] to an
/// owner as its clock.
final class ManualTimers {
  final _pending = <_ManualTimer>[];

  /// The delays of the timers not fired or cancelled, oldest first.
  List<Duration> get pending => [for (final timer in _pending) timer.delay];

  Timer start(Duration delay, void Function() callback) {
    final timer = _ManualTimer(delay, callback, _pending.remove);
    _pending.add(timer);
    return timer;
  }

  /// Fires the oldest pending timer of [delay].
  void fire(Duration delay) =>
      _pending.firstWhere((timer) => timer.delay == delay).fire();

  /// Fires every pending timer, oldest first.
  void fireAll() => [..._pending].forEach((timer) => timer.fire());
}

final class _ManualTimer implements Timer {
  _ManualTimer(this.delay, this._callback, this._forget);

  final Duration delay;
  final void Function() _callback;
  final bool Function(_ManualTimer timer) _forget;
  bool _active = true;

  void fire() {
    if (!_active) return;
    cancel();
    _callback();
  }

  @override
  void cancel() {
    _active = false;
    _forget(this);
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;
}
