/// The file owner's contract: what reaches it, what it decides, what it
/// leads to. One file owner per open document, new or existing; it keeps
/// the document's edits on the device and in its file, in step with
/// changes from elsewhere, and never loses an edit.
library;

import '../../common/moment.dart';
import '../version.dart';

/// An effect's id; its result comes back with it. Results of effects the
/// owner no longer waits for are ignored.
extension type const EffectId(int value) {}

/// Why edits must be kept now: the document closes, the app is hidden
/// (and may be ended), or the app exits.
enum SecureReason { close, hide, exit }

/// Which version a pick keeps: the edits, or the file's from elsewhere.
enum PickChoice { mine, theirs }

// Inputs.

sealed class FileInput {
  const FileInput();
}

/// The editor's text after a command changed it: its [rev] counts text
/// changes; [lineage] is the version it descends from (`null` for a new
/// document), which moves only with a [Replaced] or [Picked] applied;
/// [picks] counts the [Picked] applied.
final class Edited extends FileInput {
  const Edited(
    this.text, {
    required this.rev,
    required this.lineage,
    required this.picks,
  });

  final String text;
  final int rev;
  final Version? lineage;
  final int picks;
}

/// Write the edits into the file once the device keeps them. A new
/// document's file is created only when it is secured.
final class SaveNow extends FileInput {
  const SaveNow();
}

/// Keep the edits somewhere lasting now; answered by [Answer]. A
/// [Secure] that comes while another waits is answered with it.
final class Secure extends FileInput {
  const Secure(this.reason);

  final SecureReason reason;
}

/// What a scan that started at [startedAt] found of the file.
final class Observed extends FileInput {
  const Observed(this.observation, {required this.startedAt});

  final Observation observation;
  final Moment startedAt;
}

sealed class Observation {
  const Observation();
}

/// The file is there, holding [seen].
final class Found extends Observation {
  const Found(this.seen);

  final Seen seen;
}

/// The scan could not tell (e.g. the folder was out of reach).
final class Unknown extends Observation {
  const Unknown();
}

/// The file is gone.
final class Gone extends Observation {
  const Gone();
}

/// The user's pick between the edits at [rev] and the version [seen]
/// from elsewhere, as the compare view showed them.
final class Pick extends FileInput {
  const Pick(this.choice, {required this.seen, required this.rev});

  final PickChoice choice;
  final Version seen;
  final int rev;
}

/// Write the edits as the file again, after it was deleted elsewhere.
final class RestoreMine extends FileInput {
  const RestoreMine();
}

/// Drop the edits that could be kept nowhere (a failed write, a change
/// or deletion elsewhere), while no write or pick is under way; the text
/// goes back to the file's.
final class Discard extends FileInput {
  const Discard();
}

/// The user moved or renamed the document in the app: the owner goes on
/// with [copy].
final class Moved extends FileInput {
  const Moved(this.copy);

  final Seen copy;
}

/// Whether [KeepDraft] kept the draft.
final class DraftKept extends FileInput {
  const DraftKept(this.id, {required this.kept});

  final EffectId id;
  final bool kept;
}

/// How [Write], [Create] or [Restore] went; it ended at [endedAt].
final class Wrote extends FileInput {
  const Wrote(this.id, this.outcome, {required this.endedAt});

  final EffectId id;
  final WriteOutcome outcome;
  final Moment endedAt;
}

sealed class WriteOutcome {
  const WriteOutcome();
}

/// The file now holds [seen].
final class Written extends WriteOutcome {
  const Written(this.seen);

  final Seen seen;
}

/// The file changed since the version written over; it holds [theirs].
final class Changed extends WriteOutcome {
  const Changed(this.theirs);

  final Seen theirs;
}

/// A file is where [Restore] would put one; it holds [there].
final class Taken extends WriteOutcome {
  const Taken(this.there);

  final Seen there;
}

/// The file to write over is gone.
final class WriteGone extends WriteOutcome {
  const WriteGone();
}

/// The write failed for another reason (e.g. no access).
final class WriteFailed extends WriteOutcome {
  const WriteFailed();
}

/// Whether [BackUpBoth] backed up both versions.
final class BackedUp extends FileInput {
  const BackedUp(this.id, {required this.ok});

  final EffectId id;
  final bool ok;
}

/// Whether [KeepAsConflict] kept the copy.
final class ConflictKept extends FileInput {
  const ConflictKept(this.id, {required this.ok});

  final EffectId id;
  final bool ok;
}

// Outputs.

sealed class FileOutput {
  const FileOutput();
}

/// What the editor owner gets.
sealed class ToEditor extends FileOutput {
  const ToEditor();
}

/// The file changed elsewhere while there were no unsaved edits: the
/// editor shows [text] unless it changed its text after [ackRev].
final class Replaced extends ToEditor {
  const Replaced(this.text, {required this.version, required this.ackRev});

  final String text;
  final Version version;
  final int ackRev;
}

/// [text] to show, descending from [version]: the version from elsewhere
/// the user picked, or the file's after the edits were discarded. Always
/// shown, the editor's rev going on from [rev]; edits the editor made
/// before it are dropped. (Picking the edits changes nothing the editor
/// shows.)
final class Picked extends ToEditor {
  const Picked(this.text, {required this.version, required this.rev});

  final String text;
  final Version? version;
  final int rev;
}

/// What the app does for the owner; results come back as inputs.
sealed class FileEffect extends FileOutput {
  const FileEffect();
}

/// Keep [text], edited from the file's [base] (`null` for a new
/// document), on this device; answered by [DraftKept].
final class KeepDraft extends FileEffect {
  const KeepDraft(this.id, {required this.base, required this.text});

  final EffectId id;
  final String? base;
  final String text;
}

/// The edits are in the file, in a conflict copy, or dropped: remove the
/// draft.
final class DropDraft extends FileEffect {
  const DropDraft();
}

/// Write [text] into the file, only over [over]; back the file up first
/// if [backUpFirst] (a failed backup never stops the write). Answered by
/// [Wrote]: [Written], [Changed], [WriteGone] or [WriteFailed].
final class Write extends FileEffect {
  const Write(
    this.id,
    this.text, {
    required this.over,
    required this.backUpFirst,
  });

  final EffectId id;
  final String text;
  final Seen over;
  final bool backUpFirst;
}

/// Create the new document's file holding [text], never over an existing
/// one: a name already taken gets the next free one (" 2"). Answered by
/// [Wrote]: [Written] or [WriteFailed].
final class Create extends FileEffect {
  const Create(this.id, this.text);

  final EffectId id;
  final String text;
}

/// Write [text] as the file again where it was deleted, never over an
/// existing one; answered by [Wrote]: [Written], [Taken] or
/// [WriteFailed].
final class Restore extends FileEffect {
  const Restore(this.id, this.text);

  final EffectId id;
  final String text;
}

/// Back up [theirs] and the edits [mine] before a pick; answered by
/// [BackedUp].
final class BackUpBoth extends FileEffect {
  const BackUpBoth(this.id, {required this.theirs, required this.mine});

  final EffectId id;
  final Seen theirs;
  final String mine;
}

/// Keep [text] as a conflict copy next to the file; answered by
/// [ConflictKept].
final class KeepAsConflict extends FileEffect {
  const KeepAsConflict(this.id, this.text);

  final EffectId id;
  final String text;
}

/// The answer to [Secure]: whether the edits are kept somewhere lasting.
final class Answer extends FileOutput {
  const Answer(this.reason, {required this.kept});

  final SecureReason reason;
  final bool kept;
}

/// A pick changed nothing: no backup could be made, the version from
/// elsewhere changed again, or theirs was picked and the edits changed
/// since.
final class PickNotKept extends FileOutput {
  const PickNotKept();
}

// State.

/// Where the document stands against its file.
sealed class FileStatus {
  const FileStatus();
}

/// A new document with nothing to keep: no file, no draft.
final class Unwritten extends FileStatus {
  const Unwritten();
}

/// The file holds the text.
final class InStep extends FileStatus {
  const InStep();
}

/// There are edits the file does not hold yet; [phase] says where the
/// latest are.
final class Editing extends FileStatus {
  const Editing(this.phase);

  final EditPhase phase;
}

enum EditPhase {
  /// Only here: being kept on this device next.
  inMemory,

  /// Kept on this device; written into the file when asked.
  onDevice,

  /// Being written into the file.
  writing,
}

/// The file changed elsewhere while there were unsaved edits; edits go
/// on into the draft until the user picks against [theirs].
final class ChangedElsewhere extends FileStatus {
  const ChangedElsewhere(this.theirs);

  final Seen theirs;
}

/// The file was deleted elsewhere; edits (if any) go on into the draft
/// until the user restores the file, discards them or closes the
/// document.
final class DeletedElsewhere extends FileStatus {
  const DeletedElsewhere();
}

/// Writing failed for another reason; the edits are kept on the device.
final class SaveFailed extends FileStatus {
  const SaveFailed();
}

/// The edits are kept as a conflict copy: no more edits are taken.
final class KeptAsConflict extends FileStatus {
  const KeptAsConflict();
}

/// The document is closed with its edits kept.
final class Closed extends FileStatus {
  const Closed();
}
