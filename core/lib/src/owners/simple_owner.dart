import 'dart:async';
import 'dart:collection';

import 'owner.dart';

/// What a simple owner's code may do while it handles one input.
abstract interface class OwnerOutlet<State, Event> {
  State get state;

  /// Sets the state; listeners hear of it if it differs.
  set state(State next);

  void emit(Event event);
}

/// Handles one input start to end, with the [OwnerOutlet] of its owner.
typedef HandleInput<In, State, Event> = Future<void> Function(
  In input,
  OwnerOutlet<State, Event> out,
);

/// An [Owner] whose inputs (e.g. user actions) are run by plain async
/// code ([HandleInput]), one at a time, in the order sent; tested on
/// fakes, not as a pure machine. A handler that throws (a bug) ends it at
/// once.
final class SimpleOwner<In, State, Event> implements Owner<In, State, Event> {
  SimpleOwner(this._state, this._handle);

  final HandleInput<In, State, Event> _handle;
  final _inputs = Queue<In>();
  final _changes = StreamController<State>.broadcast(sync: true);
  final _events = StreamController<Event>.broadcast(sync: true);
  final _ended = Completer<void>();
  State _state;
  bool _running = false;
  bool _closed = false;

  late final OwnerOutlet<State, Event> _outlet = _Outlet<State, Event>(this);

  @override
  State get state => _state;

  @override
  Stream<State> get changes => _changes.stream;

  @override
  Stream<Event> get events => _events.stream;

  /// Inputs queued before [close] still run.
  @override
  void send(In input) {
    if (_closed) return;
    _inputs.add(input);
    if (!_running) unawaited(_run());
  }

  @override
  Future<void> close() {
    _closed = true;
    _endIfDone();
    return _ended.future;
  }

  Future<void> _run() async {
    _running = true;
    try {
      while (_inputs.isNotEmpty) {
        await _handleOne(_inputs.removeFirst());
      }
    } finally {
      _running = false;
      _endIfDone();
    }
  }

  /// Handles [input]. An error is a bug: it is reported where uncaught
  /// errors go, and the owner ends at once; inputs waiting are dropped, so
  /// every question to it ends unanswered.
  Future<void> _handleOne(In input) async {
    try {
      await _handle(input, _outlet);
    } on Object catch (error, stack) {
      _closed = true;
      _inputs.clear();
      Zone.current.handleUncaughtError(error, stack);
      if (!_ended.isCompleted) _ended.complete(_endStreams());
    }
  }

  void _endIfDone() {
    if (!_closed || _running || _ended.isCompleted) return;
    _ended.complete(_endStreams());
  }

  Future<void> _endStreams() async {
    await _changes.close();
    await _events.close();
  }
}

/// The way a [SimpleOwner]'s code sets its state and emits, kept from its
/// callers.
final class _Outlet<State, Event> implements OwnerOutlet<State, Event> {
  _Outlet(this._owner);

  final SimpleOwner<Object?, State, Event> _owner;

  @override
  State get state => _owner._state;

  @override
  set state(State next) {
    if (next == _owner._state) return;
    _owner
      .._state = next
      .._changes.add(next);
  }

  @override
  void emit(Event event) => _owner._events.add(event);
}
