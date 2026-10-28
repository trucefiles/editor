/// The folder state owner's contract: what reaches it, what it decides,
/// what it leads to. One per app; it keeps what the base folders hold
/// (their listings, conflicts, subfolders and marks, never file texts) in
/// step with changes, working only on what changed. Knows nothing of
/// documents, file types or sync tools.
library;

import '../changes/folder_changes.dart';
import '../common/moment.dart';
import '../common/result.dart';
import '../marks/document_marks.dart';
import '../owners/ask.dart';
import '../owners/effects.dart';
import '../scan/folder_scanner.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';

/// What the folder state owner handles: inputs anyone may send, and the
/// results of its effects.
sealed class FolderStateMessage {
  const FolderStateMessage();
}

// Inputs.

sealed class FolderStateInput extends FolderStateMessage {
  const FolderStateInput();
}

/// List every base folder again now, e.g. when the user asks or a
/// document opens; answered by [Fresh] once each was listed by a listing
/// that started after this, so the state shows every write made before.
/// Lists even while the app is not in use; waits for the first
/// [BasesChanged].
final class Refresh extends FolderStateInput implements Asking {
  const Refresh(this.ticket);

  @override
  final Ticket ticket;
}

/// The base folders to follow are now [bases], by id, each with what is
/// selected in it: a value compared for equality. A new base folder, or
/// one whose selection changed, is listed at once; the state of those no
/// longer named goes. Nothing is listed before the first.
final class BasesChanged extends FolderStateInput {
  BasesChanged(Map<String, Object> bases) : bases = Map.unmodifiable(bases);

  final Map<String, Object> bases;
}

/// What base folder [baseId]'s changes hint: paths that changed are
/// checked once changes pause; [ListAgain] lists it at once. Ignored while
/// the app is not in use.
final class Hinted extends FolderStateInput {
  const Hinted(this.baseId, this.hint);

  final String baseId;
  final ChangeHint hint;
}

/// The app wrote or deleted [paths] in base folder [baseId] at [at] (the
/// wall clock): they are checked at once, and until a listing shows a
/// later time for one, it shows [at] (some file systems report a stale
/// time right after a write).
final class AppWrote extends FolderStateInput {
  AppWrote(this.baseId, Set<RelPath> paths, {required this.at})
    : paths = Set.unmodifiable(paths);

  final String baseId;
  final Set<RelPath> paths;
  final DateTime at;
}

/// Whether the app is in use; while it is not, hints start nothing.
final class Active extends FolderStateInput {
  const Active({required this.active});

  final bool active;
}

// Results.

sealed class FolderStateResult extends FolderStateMessage {
  const FolderStateResult();
}

/// [ListBase] found [listing], listing from [startedAt].
final class ListingDone extends FolderStateResult {
  const ListingDone(this.id, this.listing, {required this.startedAt});

  final EffectId id;
  final Result<BaseListing, StoreError> listing;
  final Moment startedAt;
}

/// [CheckBase] found [part] and the marks [marks] (`null`: none asked),
/// checking from [startedAt].
final class CheckDone extends FolderStateResult {
  const CheckDone(
    this.id,
    this.part, {
    required this.marks,
    required this.startedAt,
  });

  final EffectId id;
  final Result<PartScan, StoreError> part;
  final MarksFiles? marks;
  final Moment startedAt;
}

/// A wait for changes to pause, or the longest wait, is over.
final class ChangesWaited extends FolderStateResult {
  const ChangesWaited(this.id);

  final EffectId id;
}

/// A whole base folder as listed: what its sync tool lists, and the
/// marks of all devices.
typedef BaseListing = ({FolderScan scan, MarksFiles marks});

// Events.

/// The answer to [Refresh]: every base folder was listed since.
final class Fresh implements Answering {
  const Fresh(this.ticket);

  @override
  final Ticket ticket;
}

// Effects.

sealed class FolderStateEffect {
  const FolderStateEffect();
}

/// List base folder [baseId] whole, reading only the marks files that
/// changed since [marks]; answered by [ListingDone].
final class ListBase extends FolderStateEffect {
  const ListBase(this.id, this.baseId, {required this.marks});

  final EffectId id;
  final String baseId;
  final MarksFiles marks;
}

/// Check what lies directly in [folders] of base folder [baseId], and
/// read the marks files [marksFiles] again over [marks]; answered by
/// [CheckDone].
final class CheckBase extends FolderStateEffect {
  const CheckBase(
    this.id,
    this.baseId, {
    required this.folders,
    required this.marksFiles,
    required this.marks,
  });

  final EffectId id;
  final String baseId;
  final Set<RelPath?> folders;
  final Set<RelPath> marksFiles;
  final MarksFiles marks;
}

/// Wait [delay] for changes; then [ChangesWaited].
final class WaitForChanges extends FolderStateEffect
    implements Wait<ChangesWaited> {
  const WaitForChanges(this.id, this.delay);

  @override
  final EffectId id;
  @override
  final Duration delay;

  @override
  ChangesWaited get done => ChangesWaited(id);
}
