/// The folder state owner's contract: what reaches it, what it decides,
/// what it leads to. One per app; it keeps what the folders hold
/// (their listings, conflicts, subfolders and marks, never file texts) in
/// step with changes, working only on what changed. Knows nothing of
/// files, file types or sync tools.
library;

import '../changes/folder_changes.dart';
import '../common/moment.dart';
import '../common/result.dart';
import '../marks/file_marks.dart';
import '../owners/ask.dart';
import '../owners/effects.dart';
import '../plugins/folder_id.dart';
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

/// List every folder again now, e.g. when the user asks or a
/// file opens; answered by [Fresh] once each was listed by a listing
/// that started after this, so the state shows every write made before.
/// Lists even while the app is not in use; waits for the first
/// [FoldersChanged].
final class Refresh extends FolderStateInput implements Asking {
  const Refresh(this.ticket);

  @override
  final Ticket ticket;
}

/// The folders to follow are now [folders]. A new one is listed at once;
/// the state of those no longer named goes. Nothing is listed before the
/// first.
final class FoldersChanged extends FolderStateInput {
  FoldersChanged(Set<FolderId> folders) : folders = Set.unmodifiable(folders);

  final Set<FolderId> folders;
}

/// What [folder]'s changes hint: paths that changed are
/// checked once changes pause; [ListAgain] lists it at once. Ignored while
/// the app is not in use.
final class Hinted extends FolderStateInput {
  const Hinted(this.folder, this.hint);

  final FolderId folder;
  final ChangeHint hint;
}

/// The app wrote or deleted [paths] in [folder] at [at] (the
/// wall clock): they are checked at once, and until a listing shows a
/// later time for one, it shows [at] (some file systems report a stale
/// time right after a write).
final class AppWrote extends FolderStateInput {
  AppWrote(this.folder, Set<RelPath> paths, {required this.at})
    : paths = Set.unmodifiable(paths);

  final FolderId folder;
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

/// [ListWhole] found [listing], listing from [startedAt].
final class ListingDone extends FolderStateResult {
  const ListingDone(this.id, this.listing, {required this.startedAt});

  final EffectId id;
  final Result<WholeListing, StoreError> listing;
  final Moment startedAt;
}

/// [CheckPart] found [part] and the marks [marks] (`null`: none asked),
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

/// A whole folder as listed: what its plugin lists, and the
/// marks of all devices.
typedef WholeListing = ({FolderScan scan, MarksFiles marks});

// Events.

/// The answer to [Refresh]: every folder was listed since.
final class Fresh implements Answering {
  const Fresh(this.ticket);

  @override
  final Ticket ticket;
}

// Effects.

sealed class FolderStateEffect {
  const FolderStateEffect();
}

/// List [folder] whole, reading only the marks files that
/// changed since [marks]; answered by [ListingDone].
final class ListWhole extends FolderStateEffect {
  const ListWhole(this.id, this.folder, {required this.marks});

  final EffectId id;
  final FolderId folder;
  final MarksFiles marks;
}

/// Check what lies directly in [folders] of [folder], and
/// read the marks files [marksFiles] again over [marks]; answered by
/// [CheckDone].
final class CheckPart extends FolderStateEffect {
  const CheckPart(
    this.id,
    this.folder, {
    required this.folders,
    required this.marksFiles,
    required this.marks,
  });

  final EffectId id;
  final FolderId folder;
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
