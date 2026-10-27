/// What handling one message gives: the new state, the new work (the
/// bookkeeping the machine keeps to itself), the events for everyone and
/// the effects to carry out.
typedef Step<State, Work, Event, Effect> = ({
  State state,
  Work work,
  List<Event> events,
  List<Effect> effects,
});

/// A state machine: where it starts, and its pure [step] (no I/O, no
/// clock). Its messages are the inputs anyone may send and the results
/// of its effects, two families of one [Message] type.
final class Machine<Message, State, Work, Event, Effect> {
  const Machine({
    required this.state,
    required this.work,
    required this.step,
    this.violations,
  });

  /// The state it starts in.
  final State state;

  /// The work it starts with.
  final Work work;

  final Step<State, Work, Event, Effect> Function(
    State state,
    Work work,
    Message message,
  )
  step;

  /// The machine's rules: how [state] and [work] break them, if they do
  /// (empty while they hold). Checked after every step in debug runs and
  /// in its tests.
  final List<String> Function(State state, Work work)? violations;
}
