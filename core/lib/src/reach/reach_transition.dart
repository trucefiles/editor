import '../owners/ask.dart';
import '../owners/effects.dart';
import '../owners/machine.dart';
import 'reach_contract.dart';
import 'reach_work.dart';

/// How a folder's reach is checked.
typedef ReachTiming = ({int retries, Duration retryEvery});

/// The reach owner's decision on [message] in [state], with its [work],
/// checking as [timing] says: a failed access starts a check; if the
/// folder can't be listed, it is retrying and checked every
/// `retryEvery`, up to `retries` times, then unreachable. Any access that
/// works makes it reachable.
Step<Reach, ReachWork, ReachEvent, ReachEffect> reachStep(
  ReachTiming timing,
  Reach state,
  ReachWork work,
  ReachMessage message,
) {
  final step = _Step(timing, state, work)..handle(message);
  return (
    state: step.state,
    work: step.work,
    events: step.events,
    effects: step.effects,
  );
}

/// How [state] and [work] break the reach owner's rules.
List<String> reachViolations(Reach state, ReachWork work) => [
  if (state == Reach.retrying && work.checking == null)
    'retrying with no check or wait under way',
  if (work.checking == null && work.settles.isNotEmpty)
    'a settle waits with no check under way',
];

final class _Step {
  _Step(this.timing, this.state, this.work);

  final ReachTiming timing;
  Reach state;
  ReachWork work;
  final events = <ReachEvent>[];
  final effects = <ReachEffect>[];

  void handle(ReachMessage message) {
    _handle(message);
    if (work.checking == null) _answerSettles();
  }

  void _handle(ReachMessage message) {
    switch ((message, work.checking)) {
      case (Accessed(access: Access.worked), final checking):
        state = Reach.reachable;
        if (checking case FirstCheck(:final id)) {
          _checking(FirstCheck(id, worked: true));
        }
      case (Accessed(access: Access.mayBeGone), null)
          when state == Reach.reachable:
        _check((id) => FirstCheck(id));
      case (Accessed(), _):
        break;
      case (Settle(:final ticket), _):
        _work(settles: [...work.settles, ticket]);
      case (
            FolderChecked(:final id, :final ok),
            FirstCheck(id: final at, :final worked),
          )
          when id == at:
        if (ok || worked) return _idle();
        state = Reach.retrying;
        _retryOrGiveUp(timing.retries);
      case (RetryWaited(:final id), RetryWait(id: final at, :final left))
          when id == at:
        // An access worked meanwhile: no more checks.
        if (state != Reach.retrying) return _idle();
        _check((id) => RetryCheck(id, left: left));
      case (
            FolderChecked(:final id, :final ok),
            RetryCheck(id: final at, :final left),
          )
          when id == at:
        if (ok) state = Reach.reachable;
        if (state != Reach.retrying) return _idle();
        _retryOrGiveUp(left - 1);
      case (FolderChecked() || RetryWaited(), _):
        // Not waited for.
        break;
    }
  }

  /// Waits for the next check while [left] are to go, else gives up.
  void _retryOrGiveUp(int left) {
    if (left <= 0) {
      state = Reach.unreachable;
      return _idle();
    }
    final id = _id();
    _checking(RetryWait(id, left: left));
    effects.add(WaitToRetry(id, timing.retryEvery));
  }

  void _check(Checking Function(EffectId id) checking) {
    final id = _id();
    _checking(checking(id));
    effects.add(CheckFolder(id));
  }

  void _idle() => _checking(null);

  void _answerSettles() {
    events.addAll([for (final ticket in work.settles) Settled(ticket, state)]);
    _work(settles: const []);
  }

  EffectId _id() {
    final id = EffectId(work.nextId);
    _work(nextId: work.nextId + 1);
    return id;
  }

  void _checking(Checking? checking) => work = ReachWork(
    checking: checking,
    settles: work.settles,
    nextId: work.nextId,
  );

  void _work({List<Ticket>? settles, int? nextId}) => work = ReachWork(
    checking: work.checking,
    settles: settles ?? work.settles,
    nextId: nextId ?? work.nextId,
  );
}
