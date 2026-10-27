import 'dart:async';
import 'dart:collection';

import 'effects.dart';
import 'machine.dart';
import 'owner.dart';
import 'timers.dart';

/// An [Owner] that decides by a [Machine]'s pure step and carries out its
/// effects. Only inputs ([In]) can be sent; results ([Result]) come only
/// from the effects, so no caller can fake one. Effects and work stay
/// hidden.
///
/// A step, rule or effect that throws is a bug: it is reported, and the
/// owner ends at once, so no question to it waits forever. The machine's starting effects
/// start as the owner is made. Each step,
/// in this order: the state is set; each effect starts, in
/// order, before the next message is handled ([Wait]s by the timers, the
/// rest by the handler); then [changes] and [events] fire.
final class MachineOwner<
  Message,
  In extends Message,
  Result extends Message,
  State,
  Work,
  Event,
  Effect
>
    implements Owner<In, State, Event> {
  /// [handle] carries out the effects that are no [Wait]; [startTimer]
  /// stands in for the clock in tests.
  MachineOwner(
    Machine<Message, State, Work, Event, Effect> machine, {
    this._handle,
    StartTimer? startTimer,
  }) : _machine = machine,
       _step = machine.step,
       _state = machine.state,
       _work = machine.work,
       _timers = Timers(startTimer: startTimer) {
    machine.effects.forEach(_start);
  }

  final Machine<Message, State, Work, Event, Effect> _machine;
  final Step<State, Work, Event, Effect> Function(State, Work, Message) _step;
  final EffectHandler<Effect, Result>? _handle;
  final Timers _timers;
  final _messages = Queue<Message>();
  final _changes = StreamController<State>.broadcast(sync: true);
  final _events = StreamController<Event>.broadcast(sync: true);
  final _ended = Completer<void>();
  State _state;
  Work _work;
  bool _handling = false;
  bool _closed = false;
  bool _broken = false;

  /// Effects started whose result has not come back yet.
  int _underWay = 0;

  @override
  State get state => _state;

  @override
  Stream<State> get changes => _changes.stream;

  @override
  Stream<Event> get events => _events.stream;

  @override
  void send(In input) {
    if (!_closed) _take(input);
  }

  @override
  Future<void> close() {
    _closed = true;
    _timers.close();
    _endIfQuiet();
    return _ended.future;
  }

  void _take(Message message) {
    if (_broken) return;
    _messages.add(message);
    if (_handling) return;
    _handling = true;
    try {
      while (_messages.isNotEmpty) {
        final next = _messages.removeFirst();
        try {
          _stepOn(next);
        } on Object catch (error, stack) {
          _fail(error, stack);
        }
      }
    } finally {
      _handling = false;
    }
    _endIfQuiet();
  }

  /// A bug (a step, a rule or an effect that throws): reported where
  /// uncaught errors go, and the owner ends at once. Every question to it
  /// ends unanswered; messages and results that come later are ignored.
  void _fail(Object error, StackTrace stack) {
    _closed = true;
    _broken = true;
    _messages.clear();
    _timers.close();
    Zone.current.handleUncaughtError(error, stack);
    if (!_ended.isCompleted) _ended.complete(_endStreams());
  }

  void _stepOn(Message message) {
    final step = _step(_state, _work, message);
    final changed = step.state != _state;
    _state = step.state;
    _work = step.work;
    assert(_rulesHold(), 'after $message');
    step.effects.forEach(_start);
    if (changed) _changes.add(_state);
    step.events.forEach(_events.add);
  }

  bool _rulesHold() {
    final broken = _machine.violations?.call(_state, _work) ?? const [];
    if (broken.isEmpty) return true;
    throw StateError('rules broken: ${broken.join('; ')}');
  }

  void _start(Effect effect) {
    _underWay++;
    final result = switch (effect) {
      final Wait<Result> wait => _timers.wait(wait),
      _ => switch (_handle) {
        // A handler that throws at once fails like one that fails later.
        final handle? => Future.sync(() => handle(effect)),
        null => throw StateError('no handler for $effect'),
      },
    };
    unawaited(
      result
          .then((result) {
            if (result != null) _take(result);
          }, onError: _fail)
          .whenComplete(() {
            _underWay--;
            _endIfQuiet();
          }),
    );
  }

  /// Once closed and quiet (no message handled, no effect under way), the
  /// streams end.
  void _endIfQuiet() {
    if (!_closed || _handling || _underWay > 0 || _ended.isCompleted) return;
    _ended.complete(_endStreams());
  }

  Future<void> _endStreams() async {
    await _changes.close();
    await _events.close();
  }
}
