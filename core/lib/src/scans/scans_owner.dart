import '../owners/machine.dart';
import '../owners/machine_owner.dart';
import '../owners/owner.dart';
import '../owners/timers.dart';
import 'scans_contract.dart';
import 'scans_transition.dart';
import 'scans_work.dart';

export 'scans_contract.dart';

/// The owner of when [Folder]s are scanned into a [Scan] and which scan is
/// the latest (see `scans_contract.dart`); its state is the latest scan,
/// `null` before the first.
typedef ScansOwner<Folder, Scan> =
    Owner<ScansInput<Folder, Scan>, Scan?, Fresh>;

/// The scans owner's machine.
typedef ScansMachine<Folder, Scan> =
    Machine<
      ScansMessage<Folder, Scan>,
      Scan?,
      ScansWork<Folder>,
      Fresh,
      ScansEffect<Folder, Scan>
    >;

/// Changes lead to a scan once they pause for [settle], at most [longest]
/// after the first.
ScansMachine<Folder, Scan> scansMachine<Folder, Scan>({
  Duration settle = const Duration(milliseconds: 500),
  Duration longest = const Duration(seconds: 3),
}) {
  final ChangesTiming timing = (settle: settle, longest: longest);
  return Machine(
    state: null,
    work: ScansWork<Folder>(),
    step: (state, work, message) => scansStep(timing, state, work, message),
    violations: scansViolations,
  );
}

/// The scans owner: [scan] scans the folders asked; changes wait as
/// [scansMachine] says, on [startTimer]'s clock.
ScansOwner<Folder, Scan> scansOwner<Folder, Scan>(
  Future<Scan> Function(List<Folder> folders) scan, {
  Duration settle = const Duration(milliseconds: 500),
  Duration longest = const Duration(seconds: 3),
  StartTimer? startTimer,
}) =>
    MachineOwner<
      ScansMessage<Folder, Scan>,
      ScansInput<Folder, Scan>,
      ScansResult<Folder, Scan>,
      Scan?,
      ScansWork<Folder>,
      Fresh,
      ScansEffect<Folder, Scan>
    >(
      scansMachine(settle: settle, longest: longest),
      handle: (effect) => switch (effect) {
        ScanAll(:final id, :final folders) => scan(
          folders,
        ).then((found) => Scanned<Folder, Scan>(id, found)),
        // Waits run by the owner's timers.
        WaitForChanges() => throw StateError('a wait reached the handler'),
      },
      startTimer: startTimer,
    );
