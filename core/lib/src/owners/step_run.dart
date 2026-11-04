import 'package:meta/meta.dart';

import 'machine.dart';

/// One message's handling in a machine's step: the state and work as
/// they change, and the events and effects it leads to. A machine writes
/// only [handle]; [run] gives the record its step returns.
abstract base class StepRun<Message, State, Work, Event, Effect> {
  StepRun(this.state, this.work);

  State state;
  Work work;
  final events = <Event>[];
  final effects = <Effect>[];

  /// Handles [message]: changes [state] and [work], adds [events] and
  /// [effects].
  @protected
  void handle(Message message);

  /// The state the step ends in; by default [state] as it is.
  @protected
  State get endState => state;

  /// What the step led to so far.
  Step<State, Work, Event, Effect> get result =>
      (state: endState, work: work, events: events, effects: effects);

  /// [message] handled.
  Step<State, Work, Event, Effect> run(Message message) {
    handle(message);
    return result;
  }
}
