import 'dart:async';

import 'effects.dart';

/// Starts a timer: [Timer.new] in the app, a fake clock in tests.
typedef StartTimer = Timer Function(Duration delay, void Function() callback);

/// Runs the [Wait] effects of one owner.
final class Timers {
  Timers({StartTimer? startTimer}) : _start = startTimer ?? Timer.new;

  final StartTimer _start;

  /// The waits not over yet, each with its timer.
  final _waiting = <Completer<Object?>, Timer>{};

  /// [wait]'s result once its delay is over; `null` if [close] came first.
  Future<Done?> wait<Done>(Wait<Done> wait) {
    final waited = Completer<Object?>();
    _waiting[waited] = _start(wait.delay, () {
      if (_waiting.remove(waited) != null) waited.complete(wait.done);
    });
    return waited.future.then((done) => done as Done?);
  }

  /// Ends every wait not over yet, without its result: nothing waits for
  /// time once its owner is closed.
  void close() {
    for (final MapEntry(key: waited, value: timer) in _waiting.entries) {
      timer.cancel();
      waited.complete(null);
    }
    _waiting.clear();
  }
}
