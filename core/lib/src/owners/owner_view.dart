import 'owner.dart';

/// An owner seen through another contract: each input is wrapped by
/// `input` and sent on; the owner's state and events show through
/// `state` and `event`. A new state shows only once it differs from the
/// one before. An event `event` maps to `null` doesn't show.
final class OwnerView<In, State, Event, InnerIn, InnerState, InnerEvent>
    implements Owner<In, State, Event> {
  OwnerView(
    this._inner, {
    required this._input,
    required this._state,
    required this._event,
  });

  final Owner<InnerIn, InnerState, InnerEvent> _inner;
  final InnerIn Function(In input) _input;
  final State Function(InnerState state) _state;
  final Event? Function(InnerEvent event) _event;

  @override
  void send(In input) => _inner.send(_input(input));

  @override
  State get state => _state(_inner.state);

  @override
  late final Stream<State> changes = _inner.changes.map(_state).distinct();

  @override
  Stream<Event> get events => _inner.events.expand((event) => [?_event(event)]);

  @override
  Future<void> close() => _inner.close();
}
