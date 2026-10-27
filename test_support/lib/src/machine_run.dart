import 'package:truce_core/truce_core.dart';

/// A machine stepped by hand, as a test chooses: inputs and results alike,
/// in any order. Records what each step led to; its work stays hidden, as
/// in its owner.
final class MachineRun<Message, State, Event, Effect> {
  MachineRun._(this._state, this._stepper, List<Effect> started)
    : outputs = [...started];

  /// A run of [machine] from its start.
  static MachineRun<M, S, E, F> of<M, S, W, E, F>(
    Machine<M, S, W, E, F> machine,
  ) {
    var work = machine.work;
    return MachineRun._(machine.state, (state, message) {
      final step = machine.step(state, work, message);
      work = step.work;
      return (
        state: step.state,
        led: [...step.effects, ...step.events],
        violations: machine.violations?.call(step.state, work) ?? const [],
      );
    }, machine.effects);
  }

  final _Stepper<Message, State> _stepper;
  State _state;

  State get state => _state;

  /// The starting effects, then every event and effect so far, each step's
  /// effects before its events, as the owner starts them.
  final List<Object?> outputs;

  /// How the last step broke the machine's rules; empty while they hold.
  List<String> violations = const [];

  List<Event> get events => outputs.whereType<Event>().toList();
  List<Effect> get effects => outputs.whereType<Effect>().toList();

  /// Steps [message]; returns what it led to.
  List<Object?> send(Message message) {
    final step = _stepper(_state, message);
    _state = step.state;
    violations = step.violations;
    outputs.addAll(step.led);
    return step.led;
  }

  /// The last output of type [T].
  T last<T>() => outputs.whereType<T>().last;

  /// Every output of type [T].
  List<T> all<T>() => outputs.whereType<T>().toList();
}

typedef _Stepper<Message, State> =
    ({State state, List<Object?> led, List<String> violations}) Function(
      State state,
      Message message,
    );
