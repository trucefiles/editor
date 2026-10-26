import '../../common/moment.dart';
import '../version.dart';
import 'file_contract.dart';

/// What a write in flight does.
enum WriteKind { write, create, restore, conflict }

/// A write in flight: [text] going out by [kind]; [before] the status to
/// go back to if a conflict copy fails.
typedef Writing = ({
  EffectId id,
  String text,
  WriteKind kind,
  FileStatus before,
});

/// A [Secure] being answered: [tried] once a write was tried for it,
/// [deviceRefused] once the device could not keep a draft for it.
typedef Securing = ({SecureReason reason, bool tried, bool deviceRefused});

/// The file owner's bookkeeping behind its status.
final class FileWork {
  const FileWork({
    required this.expected,
    required this.sent,
    this.nextId = 0,
    this.draft,
    this.keptRev,
    this.keepTimer,
    this.publishTimer,
    this.writing,
    this.retried = false,
    this.lastWriteEnd,
    this.backedUp,
    this.pick,
    this.wanted = false,
    this.securing,
  });

  /// What a write may go over: the version read, our last write, or a
  /// version the user picked; `null` while the document has no file.
  final Seen? expected;

  /// The version of the last [Replaced] or [Picked] sent: the lineage an
  /// [Edited] must carry.
  final Seen? sent;

  final int nextId;

  /// The draft being kept: its effect and the rev it holds.
  final ({EffectId id, int rev})? draft;

  /// The rev the draft kept on the device holds; `null` while none is.
  final int? keptRev;

  final EffectId? keepTimer;
  final EffectId? publishTimer;
  final Writing? writing;

  /// Whether the write in flight follows one that found the file only
  /// restamped, so a version that keeps changing cannot loop.
  final bool retried;

  /// When our last write ended; scans that started before are ignored.
  final Moment? lastWriteEnd;

  /// File text that needs no backup before a write over it.
  final String? backedUp;

  /// A pick waiting for its backup.
  final ({EffectId id, PickChoice choice, Seen theirs})? pick;

  /// Whether a write is wanted once the one in flight ends.
  final bool wanted;

  final Securing? securing;

  FileWork copyWith({
    Object? expected = _same,
    Object? sent = _same,
    Object? nextId = _same,
    Object? draft = _same,
    Object? keptRev = _same,
    Object? keepTimer = _same,
    Object? publishTimer = _same,
    Object? writing = _same,
    Object? retried = _same,
    Object? lastWriteEnd = _same,
    Object? backedUp = _same,
    Object? pick = _same,
    Object? wanted = _same,
    Object? securing = _same,
  }) => FileWork(
    expected: identical(expected, _same) ? this.expected : expected as Seen?,
    sent: identical(sent, _same) ? this.sent : sent as Seen?,
    nextId: identical(nextId, _same) ? this.nextId : nextId as int,
    draft: identical(draft, _same)
        ? this.draft
        : draft as ({EffectId id, int rev})?,
    keptRev: identical(keptRev, _same) ? this.keptRev : keptRev as int?,
    keepTimer: identical(keepTimer, _same)
        ? this.keepTimer
        : keepTimer as EffectId?,
    publishTimer: identical(publishTimer, _same)
        ? this.publishTimer
        : publishTimer as EffectId?,
    writing: identical(writing, _same) ? this.writing : writing as Writing?,
    retried: identical(retried, _same) ? this.retried : retried as bool,
    lastWriteEnd: identical(lastWriteEnd, _same)
        ? this.lastWriteEnd
        : lastWriteEnd as Moment?,
    backedUp: identical(backedUp, _same) ? this.backedUp : backedUp as String?,
    pick: identical(pick, _same)
        ? this.pick
        : pick as ({EffectId id, PickChoice choice, Seen theirs})?,
    wanted: identical(wanted, _same) ? this.wanted : wanted as bool,
    securing: identical(securing, _same)
        ? this.securing
        : securing as Securing?,
  );
}

/// Marks a [FileWork.copyWith] field left as it is.
const _same = Object();
