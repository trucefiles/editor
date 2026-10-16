import 'dart:async';

import '../common/result.dart';
import '../storage/file_store.dart';

/// Whether a folder's files can be reached.
enum Reach {
  reachable,

  /// An access failed and the folder could not be read: checking again for
  /// a short while. Nothing that depends on the folder should run.
  retrying,

  /// The folder could not be read for a while. Any access that works makes
  /// it [reachable] again.
  unreachable,
}

/// Tells whether one folder can be reached, from how accesses to its files
/// go (see [saw]).
///
/// An access that fails in a way that may mean the folder is out of reach
/// (not found, no access, I/O failure) starts a check: the folder itself is
/// listed, without its contents. If that works, nothing changes: e.g. one
/// file was deleted. Else the folder is [Reach.retrying] and checked every
/// [retryEvery], up to [retries] times, then [Reach.unreachable]. Any access
/// that works meanwhile or later makes it [Reach.reachable].
final class FolderReach {
  /// [store] is the folder's store whose accesses are not reported here,
  /// so checks never report themselves. [wait] stands in for the clock in
  /// tests.
  FolderReach(
    this._store, {
    this.retries = 5,
    this.retryEvery = const Duration(seconds: 1),
    this.checkTimeout = const Duration(seconds: 2),
    Future<void> Function(Duration)? wait,
  }) : _wait = wait ?? Future<void>.delayed;

  final FileStore _store;

  /// How many checks follow the first failed one before the folder is
  /// [Reach.unreachable].
  final int retries;

  final Duration retryEvery;

  /// A check that takes longer than this counts as failed.
  final Duration checkTimeout;

  final Future<void> Function(Duration) _wait;
  final _changes = StreamController<Reach>.broadcast(sync: true);
  Reach _state = Reach.reachable;
  bool _checking = false;

  Reach get state => _state;

  /// Every change of [state].
  Stream<Reach> get changes => _changes.stream;

  /// An access to the folder's files ended with [outcome].
  void saw(Result<Object?, StoreError> outcome) {
    switch (outcome) {
      case Ok():
        _set(Reach.reachable);
      case Err(
            error: StoreError.notFound ||
                StoreError.accessDenied ||
                StoreError.ioFailure,
          )
          when _state == Reach.reachable && !_checking:
        unawaited(_check());
      case Err():
        break;
    }
  }

  Future<void> _check() async {
    _checking = true;
    try {
      if (await _canRead()) return;
      if (_state != Reach.reachable) return;
      _set(Reach.retrying);
      for (var retry = 0; retry < retries; retry++) {
        await _wait(retryEvery);
        // An access worked meanwhile, or disposed.
        if (_state != Reach.retrying || _changes.isClosed) return;
        if (await _canRead()) {
          _set(Reach.reachable);
          return;
        }
      }
      if (_state == Reach.retrying) _set(Reach.unreachable);
    } finally {
      _checking = false;
    }
  }

  /// Whether the folder itself can be listed.
  Future<bool> _canRead() => _store
      .list(enterFolder: (_) => false, includeFile: (_) => false)
      .then((listed) => listed is Ok)
      .timeout(checkTimeout, onTimeout: () => false);

  /// Ignored once disposed: a check may still be running.
  void _set(Reach state) {
    if (state == _state || _changes.isClosed) return;
    _state = state;
    _changes.add(state);
  }

  /// Stops telling of changes; a running check ends at its next step.
  Future<void> dispose() => _changes.close();
}
