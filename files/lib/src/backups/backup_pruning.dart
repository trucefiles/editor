import 'package:truce_core/truce_core.dart';

import 'backup_retention.dart';

/// Deletes the backups below [root] older than [backupRetention], then
/// while they take more than the [BackupSpace] set (see
/// [pruneBackupsAt]), at most once a day or when that setting changes:
/// backups are kept for days, so a walk more often finds next to nothing
/// to delete.
final class BackupPruning {
  BackupPruning(this.root);

  /// How long after a pruning the next one is due.
  static const every = Duration(days: 1);

  final String root;

  /// When the last pruning began, and to which space; `null` before the
  /// first.
  ({DateTime at, BackupSpace space})? _last;

  /// Prunes to [space] if the last pruning began [every] or longer before
  /// [now], or pruned to another space. Failing is harmless: what is left
  /// goes the next time.
  Future<void> pruneIfDue(DateTime now, BackupSpace space) async {
    if (_last case (:final at, space: final last)
        when last == space && now.difference(at) < every) {
      return;
    }
    _last = (at: now, space: space);
    await pruneBackupsAt(
      root,
      olderThan: now.subtract(backupRetention),
      spaceLimit: space.bytes,
    );
  }
}
