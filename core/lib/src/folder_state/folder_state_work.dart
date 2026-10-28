import '../owners/ask.dart';
import '../owners/effects.dart';
import '../storage/rel_path.dart';

/// The listing or check under way: its base folder, the folders a check
/// looks at (`null` for a whole listing), and the [Refresh] tickets a
/// listing answers.
typedef Running = ({
  EffectId id,
  String baseId,
  Set<RelPath?>? checked,
  List<Ticket> answers,
});

/// A [Refresh] waiting for the base folders [left] to be listed by a
/// listing that started after it.
typedef WaitingRefresh = ({Ticket ticket, Set<String> left});

/// Changes waiting to be checked: the wait for them to pause ([settle],
/// restarted by each change) and the longest wait ([latest]).
typedef ChangesWait = ({EffectId settle, EffectId latest});

/// The folder state owner's bookkeeping behind its state.
final class FolderStateWork {
  const FolderStateWork({
    this.bases,
    this.active = true,
    this.running,
    this.refreshes = const [],
    this.early = const [],
    this.listDue = const {},
    this.checkDue = const {},
    this.hinted = const {},
    this.changes,
    this.ownWrites = const {},
    this.nextId = 0,
  });

  /// The base folders followed, with what is selected in each; `null`
  /// until the first are known.
  final Map<String, Object>? bases;

  /// Whether the app is in use.
  final bool active;

  final Running? running;

  /// [Refresh]es waiting for listings.
  final List<WaitingRefresh> refreshes;

  /// [Refresh] tickets that came before the first base folders.
  final List<Ticket> early;

  /// Base folders to list whole.
  final Set<String> listDue;

  /// Paths to check, by base folder.
  final Map<String, Set<RelPath>> checkDue;

  /// Changed paths waiting for changes to pause, by base folder.
  final Map<String, Set<RelPath>> hinted;

  /// `null` while no changes wait.
  final ChangesWait? changes;

  /// When the app last wrote each path, by base folder; kept until a
  /// listing shows a later time.
  final Map<String, Map<RelPath, DateTime>> ownWrites;

  final int nextId;

  FolderStateWork copyWith({
    Map<String, Object>? bases,
    bool? active,
    Object? running = _same,
    List<WaitingRefresh>? refreshes,
    List<Ticket>? early,
    Set<String>? listDue,
    Map<String, Set<RelPath>>? checkDue,
    Map<String, Set<RelPath>>? hinted,
    Object? changes = _same,
    Map<String, Map<RelPath, DateTime>>? ownWrites,
    int? nextId,
  }) => FolderStateWork(
    bases: bases ?? this.bases,
    active: active ?? this.active,
    running: identical(running, _same) ? this.running : running as Running?,
    refreshes: refreshes ?? this.refreshes,
    early: early ?? this.early,
    listDue: listDue ?? this.listDue,
    checkDue: checkDue ?? this.checkDue,
    hinted: hinted ?? this.hinted,
    changes: identical(changes, _same) ? this.changes : changes as ChangesWait?,
    ownWrites: ownWrites ?? this.ownWrites,
    nextId: nextId ?? this.nextId,
  );
}

/// Marks a [FolderStateWork.copyWith] field left as it is.
const _same = Object();
