/// The file owner's contract: what reaches it, what it decides, what it
/// leads to. One file owner per open file, new or existing; it keeps
/// the file's edits on the device and in its file, in step with
/// changes from elsewhere, and never loses an edit. [V] is the kind of
/// [Version] the app hands it; the owner only compares versions and hands
/// them back in its effects, typed, so the app acts on its own kind.
library;

import '../../common/moment.dart';
import '../../owners/ask.dart';
import '../../owners/effects.dart';
import '../version.dart';

/// Why edits must be kept now: the file closes, the app is hidden
/// (and may be ended), or the app exits.
enum SecureReason { close, hide, exit }

/// Which version a pick keeps: the edits, the file's from elsewhere, or
/// both merged into one (only for a type that merges).
enum PickChoice { mine, theirs, merged }

/// What the file owner handles: inputs anyone may send, and the results
/// of its effects.
sealed class FileMessage<V extends Version> {
  const FileMessage();
}

// Inputs.

sealed class FileInput<V extends Version> extends FileMessage<V> {
  const FileInput();
}

/// The editor's text after a command changed it: its [rev] counts text
/// changes; [lineage] is the version it descends from (`null` for a new
/// file), which moves only with a [Replaced] or [Picked] applied;
/// [picks] counts the [Picked] applied.
final class Edited extends FileInput<Never> {
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

/// The editor's text of a file that has no file yet, as [edited],
/// with that text's [firstLine], as the file's type reads it: its
/// file is named after it unless the user names the file.
final class NewEdited extends FileInput<Never> {
  const NewEdited(this.edited, {required this.firstLine});

  final Edited edited;
  final String firstLine;
}

/// Write the edits into the file once the device keeps them. A new
/// file is created only when it is secured.
final class SaveNow extends FileInput<Never> {
  const SaveNow();
}

/// Keep the edits somewhere lasting now; answered by [Answer]. A
/// [Secure] that comes while another waits is answered with it.
final class Secure extends FileInput<Never> implements Asking {
  const Secure(this.ticket, this.reason);

  @override
  final Ticket ticket;
  final SecureReason reason;
}

/// What a scan that started at [startedAt] found of the file.
final class Observed extends FileInput<Never> {
  const Observed(this.observation, {required this.startedAt});

  final Observation observation;
  final Moment startedAt;
}

sealed class Observation {
  const Observation();
}

/// The file is there, in [version]. A version the owner hasn't seen it
/// reads itself ([ReadLatest]).
final class Found extends Observation {
  const Found(this.version);

  final Version version;
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
final class Pick extends FileInput<Never> {
  const Pick(this.choice, {required this.seen, required this.rev});

  final PickChoice choice;
  final Version seen;
  final int rev;
}

/// Whether the edits now and the version [seen] from elsewhere can be
/// picked merged ([PickChoice.merged]), as the file's type merges them;
/// answered by [MergesAnswer].
final class AskMerges extends FileInput<Never> implements Asking {
  const AskMerges(this.ticket, {required this.seen});

  @override
  final Ticket ticket;
  final Version seen;
}

/// Write the edits as the file again, after it was deleted elsewhere.
final class RestoreMine extends FileInput<Never> {
  const RestoreMine();
}

/// Drop the edits that are in no file: those that could be kept nowhere
/// (a failed write, a change or deletion elsewhere), or a new file's
/// before its file is created; not while a write or pick is under way.
/// The text goes back to the file's: after a change elsewhere, the
/// version the file holds now.
final class Discard extends FileInput<Never> {
  const Discard();
}

/// Move or rename the file where the app was told; answered by
/// [MoveAnswer]. Edits not in the file yet are written first, so the move
/// takes every edit along; if they can't reach the file, it stays. The
/// draft goes before the move. Every [Secure] waiting is answered once it
/// ran.
final class Move extends FileInput<Never> implements Asking {
  const Move(this.ticket);

  @override
  final Ticket ticket;
}

// Results.

sealed class FileResult<V extends Version> extends FileMessage<V> {
  const FileResult();
}

/// Whether [KeepDraft] kept the draft.
final class DraftKept extends FileResult<Never> {
  const DraftKept(this.id, {required this.kept});

  final EffectId id;
  final bool kept;
}

/// How [Write], [Create] or [Restore] went; it ended at [endedAt].
final class Wrote<V extends Version> extends FileResult<V> {
  const Wrote(this.id, this.outcome, {required this.endedAt});

  final EffectId id;
  final WriteOutcome<V> outcome;
  final Moment endedAt;
}

sealed class WriteOutcome<V extends Version> {
  const WriteOutcome();
}

/// The file now holds [seen].
final class Written<V extends Version> extends WriteOutcome<V> {
  const Written(this.seen);

  final Seen<V> seen;
}

/// The file changed since the version written over; it holds [theirs].
final class Changed<V extends Version> extends WriteOutcome<V> {
  const Changed(this.theirs);

  final Seen<V> theirs;
}

/// A file is where [Restore] would put one; it holds [there].
final class Taken<V extends Version> extends WriteOutcome<V> {
  const Taken(this.there);

  final Seen<V> there;
}

/// The file to write over is gone.
final class WriteGone extends WriteOutcome<Never> {
  const WriteGone();
}

/// The write failed for another reason (e.g. no access).
final class WriteFailed extends WriteOutcome<Never> {
  const WriteFailed();
}

/// The file's folder was removed from the app, so it takes no writes.
final class FolderClosed extends WriteOutcome<Never> {
  const FolderClosed();
}

/// What [ReadLatest] read: the file now; `null` if it could not be read
/// (e.g. gone or no access), so nothing is learned.
final class LatestRead<V extends Version> extends FileResult<V> {
  const LatestRead(this.id, this.seen);

  final EffectId id;
  final Seen<V>? seen;
}

/// How [MoveFile] went, ended at [endedAt]: the file now is [copy];
/// `null` if it did not move. Scans that started before a move that
/// moved the file are ignored, as after a write.
final class MovedTo<V extends Version> extends FileResult<V> {
  const MovedTo(this.id, this.copy, {required this.endedAt});

  final EffectId id;
  final Seen<V>? copy;
  final Moment endedAt;
}

/// Whether [BackUpBoth] backed up both versions.
final class BackedUp extends FileResult<Never> {
  const BackedUp(this.id, {required this.ok});

  final EffectId id;
  final bool ok;
}

/// Whether [KeepAsConflict] kept the copy.
final class ConflictKept extends FileResult<Never> {
  const ConflictKept(this.id, {required this.ok});

  final EffectId id;
  final bool ok;
}

// Events.

sealed class FileEvent {
  const FileEvent();
}

/// What the editor owner gets.
sealed class ToEditor extends FileEvent {
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
/// shows.) Both merged: the merged text, saved as the edits are.
final class Picked extends ToEditor {
  const Picked(this.text, {required this.version, required this.rev});

  final String text;
  final Version? version;
  final int rev;
}

/// The answer to [Secure]: whether the edits are kept somewhere lasting.
final class Answer extends FileEvent implements Answering {
  const Answer(this.ticket, {required this.kept});

  @override
  final Ticket ticket;
  final bool kept;
}

/// The answer to [Move]: whether the move was started ([MoveFile]), and
/// so has ended; not when the edits can't reach the file, or another move
/// waits.
final class MoveAnswer extends FileEvent implements Answering {
  const MoveAnswer(this.ticket, {required this.started});

  @override
  final Ticket ticket;
  final bool started;
}

/// The answer to [AskMerges]: whether the two merge; `false` once the
/// version from elsewhere is another than the one asked about.
final class MergesAnswer extends FileEvent implements Answering {
  const MergesAnswer(this.ticket, {required this.merges});

  @override
  final Ticket ticket;
  final bool merges;
}

/// The file's folder was removed from the app: the file takes no more
/// writes. Told once per write that found it so.
final class FolderGone extends FileEvent {
  const FolderGone();
}

/// A pick changed nothing: no backup could be made, the version from
/// elsewhere changed again, theirs or both merged was picked and the
/// edits changed since, or the two can't be merged.
final class PickNotKept extends FileEvent {
  const PickNotKept();
}

/// Both versions were merged into one, as the user picked. [lost]: the
/// older versions, of either side, that newer ones replaced, named for
/// the user (e.g. an event's title); both versions were backed up first.
final class PickMerged extends FileEvent {
  const PickMerged({this.lost = const []});

  final List<String> lost;
}

// Effects.

/// What the app does for the owner; results come back as [FileResult]s.
sealed class FileEffect<V extends Version> {
  const FileEffect();
}

/// Keep [text], edited from the file's [base], on this device, as the
/// draft of the [file] the edits go over; both `null` for a new
/// file, whose draft goes where its file will. Answered by
/// [DraftKept].
final class KeepDraft<V extends Version> extends FileEffect<V> {
  const KeepDraft(
    this.id, {
    required this.base,
    required this.text,
    required this.file,
    this.firstLine,
  });

  final EffectId id;
  final String? base;
  final String text;
  final V? file;

  /// The first line of [text] (see [NewEdited]), for a new file's
  /// draft; `null` while it has a [file].
  final String? firstLine;
}

/// The edits are in the file, in a conflict copy, or dropped: remove the
/// draft of the [file] the edits went over (`null` for a new file).
final class DropDraft<V extends Version> extends FileEffect<V> {
  const DropDraft({required this.file});

  final V? file;
}

/// Write [text] into the file, only over [over]; back the file up first
/// if [backUpFirst] (a failed backup never stops the write). Answered by
/// [Wrote]: [Written], [Changed], [WriteGone] or [WriteFailed].
final class Write<V extends Version> extends FileEffect<V> {
  const Write(
    this.id,
    this.text, {
    required this.over,
    required this.backUpFirst,
  });

  final EffectId id;
  final String text;
  final Seen<V> over;
  final bool backUpFirst;
}

/// Create the new file holding [text], never over an existing
/// one: a name already taken gets the next free one (" 2"). Answered by
/// [Wrote]: [Written] or [WriteFailed].
final class Create extends FileEffect<Never> {
  const Create(this.id, this.text, {required this.firstLine});

  final EffectId id;
  final String text;

  /// The first line of [text] (see [NewEdited]); names the file only
  /// when the user gave no name.
  final String firstLine;
}

/// Write [text] as the file again where it was deleted, [where] it was
/// last, never over an existing one; answered by [Wrote]: [Written],
/// [Taken] or [WriteFailed].
final class Restore<V extends Version> extends FileEffect<V> {
  const Restore(this.id, this.text, {required this.where});

  final EffectId id;
  final String text;
  final Seen<V> where;
}

/// Read the file where [at] is, as it is now: an observation found a
/// version not seen yet. Answered by [LatestRead].
final class ReadLatest<V extends Version> extends FileEffect<V> {
  const ReadLatest(this.id, {required this.at});

  final EffectId id;
  final Seen<V> at;
}

/// Move the file, as it is at [from], where the app was told for the
/// [Move] with [ticket]; answered by [MovedTo].
final class MoveFile<V extends Version> extends FileEffect<V> {
  const MoveFile(this.id, {required this.ticket, required this.from});

  final EffectId id;
  final Ticket ticket;
  final Seen<V> from;
}

/// Back up [theirs] and the edits [mine] before a pick; answered by
/// [BackedUp].
final class BackUpBoth<V extends Version> extends FileEffect<V> {
  const BackUpBoth(this.id, {required this.theirs, required this.mine});

  final EffectId id;
  final Seen<V> theirs;
  final String mine;
}

/// Keep [text] as a conflict copy next to the file, as it is at
/// [nextTo]; answered by [ConflictKept].
final class KeepAsConflict<V extends Version> extends FileEffect<V> {
  const KeepAsConflict(this.id, this.text, {required this.nextTo});

  final EffectId id;
  final String text;
  final Seen<V> nextTo;
}

// State.

/// Where the file stands against its file. Statuses are equal when
/// they are the same case with equal fields.
sealed class FileStatus<V extends Version> {
  const FileStatus();

  /// Equal by case only: a case with fields must compare them in its own
  /// `==`, or the owner's `changes` would miss a change of them.
  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// A new file with nothing to keep: no file, no draft.
final class Unwritten extends FileStatus<Never> {
  const Unwritten();
}

/// The file holds the text.
final class InStep extends FileStatus<Never> {
  const InStep();
}

/// There are edits the file does not hold yet; [phase] says where the
/// latest are.
final class Editing extends FileStatus<Never> {
  const Editing(this.phase);

  final EditPhase phase;

  @override
  bool operator ==(Object other) => other is Editing && other.phase == phase;

  @override
  int get hashCode => phase.hashCode;
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
/// on into the draft until the user picks against [theirs] (whether the
/// two merge: [AskMerges]).
final class ChangedElsewhere<V extends Version> extends FileStatus<V> {
  const ChangedElsewhere(this.theirs);

  final Seen<V> theirs;

  @override
  bool operator ==(Object other) =>
      other is ChangedElsewhere && other.theirs == theirs;

  @override
  int get hashCode => theirs.hashCode;
}

/// The file was deleted elsewhere; edits (if any) go on into the draft
/// until the user restores the file, discards them or closes the
/// file.
final class DeletedElsewhere extends FileStatus<Never> {
  const DeletedElsewhere();
}

/// Writing failed for another reason; the edits are kept on the device.
final class SaveFailed extends FileStatus<Never> {
  const SaveFailed();
}

/// The edits are kept as a conflict copy: no more edits are taken.
final class KeptAsConflict extends FileStatus<Never> {
  const KeptAsConflict();
}

/// The file is closed with its edits kept.
final class Closed extends FileStatus<Never> {
  const Closed();
}
