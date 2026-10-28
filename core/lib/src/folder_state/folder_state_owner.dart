import '../common/moment.dart';
import '../common/result.dart';
import '../marks/document_marks.dart';
import '../owners/effects.dart';
import '../owners/machine.dart';
import '../owners/machine_owner.dart';
import '../owners/owner.dart';
import '../owners/timers.dart';
import '../scan/folder_scanner.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import 'folder_state.dart';
import 'folder_state_contract.dart';
import 'folder_state_transition.dart';
import 'folder_state_work.dart';

export 'folder_state.dart';
export 'folder_state_contract.dart';

/// The owner of what the base folders hold (see
/// `folder_state_contract.dart`).
typedef FolderStateOwner = Owner<FolderStateInput, FolderState, Fresh>;

/// The folder state owner's machine.
typedef FolderStateMachine =
    Machine<
      FolderStateMessage,
      FolderState,
      FolderStateWork,
      Fresh,
      FolderStateEffect
    >;

/// Changes are checked once they pause for [settle], at most [longest]
/// after the first.
FolderStateMachine folderStateMachine({
  Duration settle = const Duration(milliseconds: 500),
  Duration longest = const Duration(seconds: 3),
}) {
  final ChangesTiming timing = (settle: settle, longest: longest);
  return Machine(
    state: FolderState.none,
    work: const FolderStateWork(),
    step: (state, work, message) =>
        folderStateStep(timing, state, work, message),
    violations: folderStateViolations,
  );
}

/// How the folder state owner reads one base folder: what its sync tool
/// lists ([scanner]) and the marks of all devices ([marks]).
typedef BaseFolderReader = ({FolderScanner scanner, DocumentMarks marks});

/// The folder state owner: reads each base folder through
/// [readerOf]; changes wait as [folderStateMachine] says, on
/// [startTimer]'s clock.
FolderStateOwner folderStateOwner(
  BaseFolderReader Function(String baseId) readerOf, {
  Duration settle = const Duration(milliseconds: 500),
  Duration longest = const Duration(seconds: 3),
  StartTimer? startTimer,
}) =>
    MachineOwner<
      FolderStateMessage,
      FolderStateInput,
      FolderStateResult,
      FolderState,
      FolderStateWork,
      Fresh,
      FolderStateEffect
    >(
      folderStateMachine(settle: settle, longest: longest),
      handle: (effect) => switch (effect) {
        ListBase(:final id, :final baseId, :final marks) => _list(
          id,
          readerOf(baseId),
          marks,
        ),
        CheckBase(
          :final id,
          :final baseId,
          :final folders,
          :final marksFiles,
          :final marks,
        ) =>
          _check(id, readerOf(baseId), folders, marksFiles, marks),
        // Waits run by the owner's timers.
        WaitForChanges() => throw StateError('a wait reached the handler'),
      },
      startTimer: startTimer,
      // What the base folders hold matters only while someone listens.
      dropsNewWorkOnClose: true,
    );

/// Lists [reader]'s base folder whole, its marks files on the same walk.
Future<ListingDone> _list(
  EffectId id,
  BaseFolderReader reader,
  MarksFiles known,
) async {
  final startedAt = Moment.now();
  final scan = await reader.scanner.scan(also: DocumentMarks.files);
  final Result<BaseListing, StoreError> listing = switch (scan) {
    Ok(value: final scan) => Ok((
      scan: scan,
      marks: await reader.marks.loadListed(scan.alsoListed, known: known),
    )),
    Err(:final error) => Err(error),
  };
  return ListingDone(id, listing, startedAt: startedAt);
}

/// Checks [folders] and reads [marksFiles] again in [reader]'s base
/// folder.
Future<CheckDone> _check(
  EffectId id,
  BaseFolderReader reader,
  Set<RelPath?> folders,
  Set<RelPath> marksFiles,
  MarksFiles known,
) async {
  final startedAt = Moment.now();
  final part = folders.isEmpty
      ? const Ok<PartScan, StoreError>(PartScan.nothing)
      : await reader.scanner.scanIn(folders);
  final marks = marksFiles.isEmpty
      ? null
      : await reader.marks.reload(known, marksFiles);
  return CheckDone(id, part, marks: marks, startedAt: startedAt);
}
