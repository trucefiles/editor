import '../common/moment.dart';
import '../common/result.dart';
import '../owners/effects.dart';
import '../owners/machine.dart';
import '../owners/machine_owner.dart';
import '../owners/owner.dart';
import '../storage/file_store.dart';
import '../versions/resolution.dart';
import '../versions/resolve_error.dart';
import 'compare_contract.dart';
import 'compare_transition.dart';
import 'compare_work.dart';

export 'compare_contract.dart';

/// The owner of one compare screen (see `compare_contract.dart`).
typedef CompareOwner<Target, Sides> =
    Owner<CompareInput<Target, Sides>, CompareState<Target, Sides>, KeepAnswer>;

/// The compare owner's machine.
typedef CompareMachine<Target, Sides> =
    Machine<
      CompareMessage<Target, Sides>,
      CompareState<Target, Sides>,
      CompareWork,
      KeepAnswer,
      CompareEffect<Target, Sides>
    >;

/// Where a comparison's sides come from and where a keep goes.
abstract interface class CompareSource<Target, Sides> {
  /// The two versions of [target] to compare.
  Future<Result<Sides, StoreError>> load(Target target);

  /// Keeps [choice] of [sides] of [target], only over the versions shown.
  Future<Result<void, ResolveError>> keep(
    Target target,
    Sides sides,
    Resolution choice,
  );

  /// Scans the folders again, so a scan shows the keep.
  Future<void> rescan();
}

/// The compare machine, loading [start] first. With [goesOn], a keep that
/// worked goes on to the next target a scan finds (conflict copies, one
/// by one); else it ends the comparison (a backup restored).
CompareMachine<Target, Sides> compareMachine<Target, Sides>(
  Target start, {
  required bool goesOn,
}) => Machine(
  state: CompareLoading(start),
  work: const CompareWork(loading: EffectId(0), nextId: 1),
  effects: [LoadSides(const EffectId(0), start)],
  step: (state, work, message) => compareStep(goesOn, state, work, message),
  violations: compareViolations,
);

/// The compare owner of [start], whose sides and keeps go through
/// [source]; see [compareMachine] for [goesOn].
CompareOwner<Target, Sides> compareOwner<Target, Sides>(
  Target start,
  CompareSource<Target, Sides> source, {
  required bool goesOn,
}) =>
    MachineOwner<
      CompareMessage<Target, Sides>,
      CompareInput<Target, Sides>,
      CompareResult<Target, Sides>,
      CompareState<Target, Sides>,
      CompareWork,
      KeepAnswer,
      CompareEffect<Target, Sides>
    >(
      compareMachine(start, goesOn: goesOn),
      handle: (effect) => switch (effect) {
        LoadSides(:final id, :final target) =>
          source
              .load(target)
              .then((sides) => SidesLoaded<Target, Sides>(id, sides)),
        KeepChoice(:final id, :final target, :final sides, :final choice) =>
          source
              .keep(target, sides, choice)
              .then(
                (outcome) => KeepEnded<Target, Sides>(
                  id,
                  outcome,
                  endedAt: Moment.now(),
                ),
              ),
        RescanAfterKeep() => source.rescan().then((_) => null),
      },
    );
