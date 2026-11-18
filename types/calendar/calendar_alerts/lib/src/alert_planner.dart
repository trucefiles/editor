import 'dart:async';

import 'package:truce_core/truce_core.dart';

import 'planner_contract.dart';
import 'planning.dart';
import 'ring_state.dart';
import 'ringer.dart';

/// The owner of when alerts ring on this device: it plans each input as
/// [planStep] says, one at a time, hands the changes to its [Ringer],
/// tells the missed ones, then keeps its [RingState] in its store. Its
/// kept state is loaded with the first input. Each time the ringer rings
/// an alert itself it hears of it ([Rang]).
final class AlertPlanner implements Owner<PlannerInput, PlannerState, Handled> {
  AlertPlanner({required this._ringer, required this._store}) {
    _rang = _ringer.rang.listen((now) => send(Rang(now: now)));
  }

  final Ringer _ringer;
  final SettingStore<RingState> _store;
  late final _owner = SimpleOwner<PlannerInput, PlannerState, Handled>(
    const PlannerState(ring: RingState.none),
    _handle,
  );

  /// Whether the kept state was loaded.
  var _loaded = false;
  late final StreamSubscription<DateTime> _rang;

  @override
  void send(PlannerInput input) => _owner.send(input);

  @override
  PlannerState get state => _owner.state;

  @override
  Stream<PlannerState> get changes => _owner.changes;

  @override
  Stream<Handled> get events => _owner.events;

  @override
  Future<void> close() async {
    await _rang.cancel();
    await _owner.close();
  }

  /// Sends [input] and completes once it is handled; at once if the
  /// planner ended.
  Future<void> handle(PlannerInput Function(Ticket ticket) input) =>
      ask<PlannerInput, Handled>(send, events, input);

  Future<void> _handle(
    PlannerInput input,
    OwnerOutlet<PlannerState, Handled> out,
  ) async {
    final (ringer, store) = (_ringer, _store);
    final state = _loaded ? out.state : PlannerState(ring: await store.load());
    _loaded = true;
    final (state: planned, :changes, :missed) = planStep(
      state,
      input,
      ringsWhileClosed: ringer.ringsWhileClosed,
    );
    final next = changes.isEmpty
        ? planned
        : withoutRefused(planned, await ringer.apply(changes));
    if (missed.isNotEmpty) await ringer.showMissed(missed);
    // Kept once rung: a state that says more than the ringer holds would
    // count an alert as rung that never was. Only a change is written.
    if (next.ring != state.ring) await store.save(next.ring);
    out
      ..state = next
      ..emit(Handled(input.ticket));
  }
}
