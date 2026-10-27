import '../common/result.dart';
import '../owners/ask.dart';
import '../owners/effects.dart';
import '../owners/machine.dart';
import '../versions/resolution.dart';
import 'compare_contract.dart';
import 'compare_work.dart';

/// The compare owner's decision on [message] in [state], with its [work].
/// After a keep, the next target comes only from a scan that started
/// after the keep ended; with [goesOn], a keep that worked goes on to it
/// (conflict copies, one by one), else it ends the comparison (a backup
/// restored).
Step<
  CompareState<Target, Sides>,
  CompareWork,
  KeepAnswer,
  CompareEffect<Target, Sides>
>
compareStep<Target, Sides>(
  bool goesOn,
  CompareState<Target, Sides> state,
  CompareWork work,
  CompareMessage<Target, Sides> message,
) {
  final step = _Step<Target, Sides>(goesOn, state, work)..handle(message);
  return (
    state: step.state,
    work: step.work,
    events: step.events,
    effects: step.effects,
  );
}

/// How [state] and [work] break the compare owner's rules.
List<String> compareViolations<Target, Sides>(
  CompareState<Target, Sides> state,
  CompareWork work,
) => [
  if ((state is CompareKeeping) != (work.keep != null))
    'a keep is under way exactly while keeping',
  if ((state is CompareLoading) != (work.loading != null))
    'a load is under way exactly while loading',
];

final class _Step<Target, Sides> {
  _Step(this.goesOn, this.state, this.work);

  final bool goesOn;
  CompareState<Target, Sides> state;
  CompareWork work;
  final events = <KeepAnswer>[];
  final effects = <CompareEffect<Target, Sides>>[];

  void handle(CompareMessage<Target, Sides> message) {
    switch ((message, state)) {
      case (
        Keep(:final ticket, :final choice),
        CompareShowing(:final target, :final sides),
      ):
        _keep(ticket, target, sides, choice);
      case (Keep(:final ticket), _):
        events.add(KeepAnswer(ticket, taken: false));
      case (SidesLoaded(:final id, :final sides), CompareLoading(:final target))
          when id == work.loading:
        work = work.copyWith(loading: null);
        state = switch (sides) {
          Ok(value: final sides) => CompareShowing(target, sides),
          Err(:final error) => CompareLoadFailed(target, error),
        };
      case (SidesLoaded(), _):
        break;
      case (KeepEnded(:final id, :final outcome, :final endedAt), _)
          when id == work.keep?.id:
        final keep = work.keep!;
        work = work.copyWith(
          keep: (
            ticket: keep.ticket,
            id: keep.id,
            endedAt: endedAt,
            error: switch (outcome) {
              Err(:final error) => error,
              Ok() => null,
            },
          ),
        );
        effects.add(const RescanAfterKeep());
      case (KeepEnded(), _):
        break;
      case (
        ScanSeen(:final next, :final startedAt),
        CompareKeeping(:final target, :final sides),
      ):
        // Only a scan that started after the keep ended shows it.
        if (work.keep!.endedAt case final endedAt?
            when !startedAt.isBefore(endedAt)) {
          _afterKeep(work.keep!, next, CompareDone(target, sides));
        }
      case (ScanSeen(:final next), CompareLoadFailed(:final target)):
        _load(next ?? target);
      case (ScanSeen(), _):
        break;
    }
  }

  void _keep(Ticket ticket, Target target, Sides sides, Resolution choice) {
    final id = _nextId();
    work = work.copyWith(
      keep: (ticket: ticket, id: id, endedAt: null, error: null),
    );
    state = CompareKeeping(target, sides);
    effects.add(KeepChoice(id, target, sides, choice));
  }

  /// [keep] ended, and a scan after it found [next]; [done] if nothing
  /// is left to compare.
  void _afterKeep(
    KeepUnderWay keep,
    Target? next,
    CompareDone<Target, Sides> done,
  ) {
    work = work.copyWith(keep: null);
    final isDone = next == null || (keep.error == null && !goesOn);
    if (isDone) {
      state = done;
    } else {
      _load(next);
    }
    events.add(
      KeepAnswer(keep.ticket, taken: true, error: keep.error, done: isDone),
    );
  }

  void _load(Target target) {
    final id = _nextId();
    work = work.copyWith(loading: id);
    state = CompareLoading(target);
    effects.add(LoadSides(id, target));
  }

  EffectId _nextId() {
    final id = EffectId(work.nextId);
    work = work.copyWith(nextId: work.nextId + 1);
    return id;
  }
}
