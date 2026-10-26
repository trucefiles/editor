import 'dart:async';
import 'dart:collection';

/// The owner of one domain's state: inputs reach it from any source at
/// any time; it handles them in order, one at a time, and decides its
/// new [state]; [outputs] tell other owners and listeners what follows.
abstract interface class Owner<In, State, Out> {
  /// Handles [input] before it returns, unless an input is being handled:
  /// then right after that one.
  void send(In input);

  /// The state after the inputs handled so far.
  State get state;

  /// What the inputs lead to, each after its input is handled.
  Stream<Out> get outputs;
}

/// What handling one input gives: the owner's new state, its new work
/// (the bookkeeping it keeps to itself) and its outputs.
typedef Step<State, Work, Out> = ({State state, Work work, List<Out> outputs});

/// An [Owner] that decides by a pure [transition]; only its state is
/// public, its work stays its own.
final class TransitionOwner<In, State, Work, Out>
    implements Owner<In, State, Out> {
  TransitionOwner(this._state, this._work, this._transition);

  final Step<State, Work, Out> Function(State state, Work work, In input)
  _transition;
  final _inputs = Queue<In>();
  final _outputs = StreamController<Out>.broadcast(sync: true);
  State _state;
  Work _work;
  bool _handling = false;

  @override
  State get state => _state;

  @override
  Stream<Out> get outputs => _outputs.stream;

  @override
  void send(In input) {
    _inputs.add(input);
    if (_handling) return;
    _handling = true;
    try {
      while (_inputs.isNotEmpty) {
        final step = _transition(_state, _work, _inputs.removeFirst());
        _state = step.state;
        _work = step.work;
        step.outputs.forEach(_outputs.add);
      }
    } finally {
      _handling = false;
    }
  }

  /// Ends [outputs]; no input may follow.
  Future<void> close() => _outputs.close();
}
