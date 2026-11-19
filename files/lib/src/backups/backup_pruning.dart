import 'package:truce_core/truce_core.dart';

import 'backup_retention.dart';

/// Deletes the backups below [root] older than [backupRetention], then
/// while they take more than the [BackupSpace] set (see
/// [pruneBackupsAt]), at most once a day or when that setting changes:
/// backups are kept for days, so a walk more often finds next to nothing
/// to delete. One pruning runs at a time; one pruning to a space no
/// longer set stops deleting for space. Only backups of the files the
/// app [shows] count toward the space.
final class BackupPruning {
  BackupPruning(this.root, {required this.shows});

  /// How long after a pruning the next one is due.
  static const every = Duration(days: 1);

  final String root;
  final bool Function(RelPath file) shows;

  /// When the last pruning began, and to which space; `null` before the
  /// first.
  ({DateTime at, BackupSpace space})? _last;

  /// The space set last.
  BackupSpace? _wanted;

  /// The pruning running or queued last; done before the next begins.
  Future<void> _running = Future.value();

  /// Prunes to [space] if the last pruning began [every] or longer before
  /// [now], or pruned to another space. Failing is harmless: what is left
  /// goes the next time.
  Future<void> pruneIfDue(DateTime now, BackupSpace space) {
    _wanted = space;
    if (_last case (:final at, space: final last)
        when last == space && now.difference(at) < every) {
      return _running;
    }
    _last = (at: now, space: space);
    return _running = _running.then(
      (_) => pruneBackupsAt(
        root,
        olderThan: now.subtract(backupRetention),
        counts: shows,
        spaceLimit: space.bytes,
        goOn: () => _wanted == space,
      ),
    );
  }
}
