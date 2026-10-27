import '../owners/ask.dart';
import '../owners/effects.dart';

/// The scan under way, and the [Refresh] tickets it answers.
typedef Running = ({EffectId id, List<Ticket> answers});

/// Changes waiting to lead to a scan: the wait for them to pause
/// ([settle], restarted by each change) and the longest wait ([latest]).
typedef ChangesWait = ({EffectId settle, EffectId latest});

/// The scans owner's bookkeeping behind its state.
final class ScansWork<Folder> {
  const ScansWork({
    this.folders,
    this.active = true,
    this.running,
    this.waiting = const [],
    this.due = false,
    this.changes,
    this.nextId = 0,
  });

  /// The folders to scan; `null` until the first are known.
  final List<Folder>? folders;

  /// Whether the app is in use.
  final bool active;

  final Running? running;

  /// Tickets for the next scan: they came after the one under way began.
  final List<Ticket> waiting;

  /// A scan is due without a ticket (a change, new folders).
  final bool due;

  /// `null` while no changes wait.
  final ChangesWait? changes;

  final int nextId;

  ScansWork<Folder> copyWith({
    List<Folder>? folders,
    bool? active,
    Object? running = _same,
    List<Ticket>? waiting,
    bool? due,
    Object? changes = _same,
    int? nextId,
  }) => ScansWork(
    folders: folders ?? this.folders,
    active: active ?? this.active,
    running: identical(running, _same) ? this.running : running as Running?,
    waiting: waiting ?? this.waiting,
    due: due ?? this.due,
    changes: identical(changes, _same) ? this.changes : changes as ChangesWait?,
    nextId: nextId ?? this.nextId,
  );
}

/// Marks a [ScansWork.copyWith] field left as it is.
const _same = Object();
