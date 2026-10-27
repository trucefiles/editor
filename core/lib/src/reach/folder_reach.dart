import 'dart:async';

import '../common/result.dart';
import '../owners/machine.dart';
import '../owners/machine_owner.dart';
import '../owners/owner.dart';
import '../owners/timers.dart';
import '../storage/file_store.dart';
import 'reach_contract.dart';
import 'reach_transition.dart';
import 'reach_work.dart';

export 'reach_contract.dart';

/// The owner of whether one folder's files can be reached (see
/// `reach_contract.dart`).
typedef FolderReach = Owner<ReachInput, Reach, ReachEvent>;

/// The reach owner's machine.
typedef ReachMachine =
    Machine<ReachMessage, Reach, ReachWork, ReachEvent, ReachEffect>;

/// The reach machine: retries [retries] times, [retryEvery] apart, after
/// a failed check.
ReachMachine reachMachine({
  int retries = 5,
  Duration retryEvery = const Duration(seconds: 1),
}) {
  final ReachTiming timing = (retries: retries, retryEvery: retryEvery);
  return Machine(
    state: Reach.reachable,
    work: const ReachWork(),
    step: (state, work, message) => reachStep(timing, state, work, message),
    violations: reachViolations,
  );
}

/// The reach owner of the folder in [store], whose accesses are not
/// reported to it, so checks never report themselves. A check that takes
/// longer than [checkTimeout] counts as failed; [startTimer] stands in for
/// the clock in tests.
FolderReach folderReach(
  FileStore store, {
  int retries = 5,
  Duration retryEvery = const Duration(seconds: 1),
  Duration checkTimeout = const Duration(seconds: 2),
  StartTimer? startTimer,
}) =>
    MachineOwner<
      ReachMessage,
      ReachInput,
      ReachResult,
      Reach,
      ReachWork,
      ReachEvent,
      ReachEffect
    >(
      reachMachine(retries: retries, retryEvery: retryEvery),
      handle: (effect) => switch (effect) {
        CheckFolder(:final id) => _canRead(
          store,
          checkTimeout,
        ).then((ok) => FolderChecked(id, ok: ok)),
        // Waits run by the owner's timers.
        WaitToRetry() => throw StateError('a wait reached the handler'),
      },
      startTimer: startTimer,
    );

/// Whether the folder in [store] itself can be listed within [timeout].
Future<bool> _canRead(FileStore store, Duration timeout) => store
    .list(enterFolder: (_) => false, includeFile: (_) => false)
    .then((listed) => listed is Ok)
    .timeout(timeout, onTimeout: () => false);

/// How an access that ended with [outcome] went, for the reach.
Access accessOf(Result<Object?, StoreError> outcome) => switch (outcome) {
  Ok() => Access.worked,
  Err(
    error: StoreError.notFound ||
        StoreError.accessDenied ||
        StoreError.ioFailure,
  ) =>
    Access.mayBeGone,
  Err() => Access.otherError,
};
