/// The owner of one domain's state: inputs reach it from any source at
/// any time; it handles them in order, one at a time, and decides its
/// new [state]; [events] tell other owners and listeners what follows.
abstract interface class Owner<In, State, Event> {
  /// Queues [input]; it is handled after every input sent before it.
  /// Dropped once the owner is closed.
  void send(In input);

  /// The state after the inputs handled so far.
  State get state;

  /// Each new state, once it differs from the one before (`!=`).
  Stream<State> get changes;

  /// What the inputs lead to: notices, answers, what other owners get.
  /// Each fires after its step's state is set.
  Stream<Event> get events;

  /// Takes no more inputs; work under way still ends and its outcome is
  /// still handled. Then [changes] and [events] end, and this completes.
  Future<void> close();
}
