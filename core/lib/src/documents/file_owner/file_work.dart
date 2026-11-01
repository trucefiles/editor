import 'package:collection/collection.dart';

import '../../common/moment.dart';
import '../../owners/effects.dart';
import '../version.dart';
import 'file_contract.dart';

/// The one I/O under way; the owner starts the next only once it ended.
sealed class Io<V extends Version> {
  const Io(this.id);

  final EffectId id;
}

/// Keeping [text] on the device as the draft.
final class KeepingDraft extends Io<Never> {
  const KeepingDraft(super.id, this.text);

  final String text;
}

/// How a write reaches the file.
enum WriteKind {
  /// Over the version expected.
  write,

  /// Over the version expected again, after a write found it only
  /// restamped: one more find is a change elsewhere, so a file that keeps
  /// changing cannot loop.
  rewrite,

  /// The new document's file.
  create,

  /// The file again, after it was deleted elsewhere.
  restore,
}

/// Writing [text], the editor's at [rev], into the file by [kind].
final class WritingFile extends Io<Never> {
  const WritingFile(
    super.id,
    this.text, {
    required this.rev,
    required this.kind,
  });

  final String text;
  final int rev;
  final WriteKind kind;
}

/// Reading the file as it is now, where it was [at] when the read began.
final class ReadingFile<V extends Version> extends Io<V> {
  const ReadingFile(super.id, {required this.at});

  final Seen<V> at;
}

/// Moving the file where the app was told, for [ask].
final class MovingFile extends Io<Never> {
  const MovingFile(super.id, this.ask);

  final Move ask;
}

/// Backing up both versions for [pick].
final class BackingUp extends Io<Never> {
  const BackingUp(super.id, this.pick);

  final Pick pick;
}

/// Keeping the edits as a conflict copy; [before] the status to go back
/// to if it fails.
final class KeepingConflict<V extends Version> extends Io<V> {
  const KeepingConflict(super.id, {required this.before});

  final FileStatus<V> before;
}

/// What the device holds of the edits.
sealed class Draft {
  const Draft(this.text);

  final String text;
}

/// The device keeps [text].
final class KeptDraft extends Draft {
  const KeptDraft(super.text);
}

/// The device could not keep [text].
final class RefusedDraft extends Draft {
  const RefusedDraft(super.text);
}

/// How far keeping the edits for a [Secure] went: each rung is tried
/// once, then the next.
enum SecureRung {
  /// Into the file.
  file,

  /// Onto the device (not for a close of a document that has a file).
  device,

  /// As a conflict copy next to the file.
  conflict,
}

/// The [Secure]s waiting for one answer, and how far keeping went.
typedef Securing = ({List<Secure> asks, SecureRung rung});

/// The file owner's bookkeeping behind its status.
final class FileWork<V extends Version> {
  const FileWork({
    required this.expected,
    required this.offered,
    this.editsOver,
    this.picks = 0,
    this.nextId = 0,
    this.io,
    this.draft,
    this.folderRev,
    this.pick,
    this.securing,
    this.lastWriteEnd,
    this.backedUp,
    this.created,
    this.move,
    this.toRead,
    this.firstLine,
  });

  /// What a write may go over: the version read, our last write, or a
  /// version the user picked; `null` while the document has no file.
  final Seen<V>? expected;

  /// The versions the editor may show: the last one it surely took, then
  /// each [Replaced] sent since.
  final List<Seen<V>> offered;

  /// The version of the last [Replaced] or [Picked] sent: the lineage an
  /// [Edited] must carry.
  Seen<V>? get sent => offered.lastOrNull;

  /// The version the edits were made over, where [expected] moved past
  /// it: a change elsewhere the editor did not take.
  final Seen<V>? editsOver;

  /// How many [Picked] were sent: an [Edited] made before the last one
  /// names fewer.
  final int picks;

  final int nextId;

  /// The I/O under way; `null` while none is.
  final Io<V>? io;

  /// What the device holds of the edits; `null` while it holds none.
  final Draft? draft;

  /// The editor's rev the file is asked to hold; `null` while no write
  /// is asked.
  final int? folderRev;

  /// A pick waiting for the I/O under way.
  final Pick? pick;

  final Securing? securing;

  /// When our last write ended; scans that started before are ignored.
  final Moment? lastWriteEnd;

  /// File text that needs no backup before a write over it.
  final String? backedUp;

  /// The version this owner created the new document's file in: the
  /// lineage of edits that name none, made before the editor took a
  /// version.
  final Version? created;

  /// A move waiting for the I/O under way or for its edits to be written.
  final Move? move;

  /// A version of the file an observation found, not seen yet: read once
  /// no I/O is under way.
  final Version? toRead;

  /// The first line of a new document's text, as the last [NewEdited]
  /// said with it; `null` once it has a file.
  final String? firstLine;

  FileWork<V> copyWith({
    Object? expected = _same,
    Object? offered = _same,
    Object? editsOver = _same,
    Object? picks = _same,
    Object? nextId = _same,
    Object? io = _same,
    Object? draft = _same,
    Object? folderRev = _same,
    Object? pick = _same,
    Object? securing = _same,
    Object? lastWriteEnd = _same,
    Object? backedUp = _same,
    Object? created = _same,
    Object? move = _same,
    Object? toRead = _same,
    Object? firstLine = _same,
  }) => FileWork(
    expected: _or(expected, this.expected),
    offered: _or(offered, this.offered),
    editsOver: _or(editsOver, this.editsOver),
    picks: _or(picks, this.picks),
    nextId: _or(nextId, this.nextId),
    io: _or(io, this.io),
    draft: _or(draft, this.draft),
    folderRev: _or(folderRev, this.folderRev),
    pick: _or(pick, this.pick),
    securing: _or(securing, this.securing),
    lastWriteEnd: _or(lastWriteEnd, this.lastWriteEnd),
    backedUp: _or(backedUp, this.backedUp),
    created: _or(created, this.created),
    move: _or(move, this.move),
    toRead: _or(toRead, this.toRead),
    firstLine: _or(firstLine, this.firstLine),
  );
}

/// Marks a [FileWork.copyWith] field left as it is.
const _same = Object();

/// [given], or [current] where it was left as it is.
T _or<T>(Object? given, T current) =>
    identical(given, _same) ? current : given as T;
