import 'package:truce_core/truce_core.dart';

import 'backup_retention.dart';

/// Deletes the backups below [root] older than [backupRetention] (see
/// [pruneBackupsAt]), at most once a day: backups are kept for days, so
/// a walk more often finds next to nothing to delete.
final class BackupPruning {
  BackupPruning(this.root);

  /// How long after a pruning the next one is due.
  static const every = Duration(days: 1);

  final String root;

  /// When the last pruning began; `null` before the first.
  DateTime? _last;

  /// Prunes if the last pruning began [every] or longer before [now].
  /// Failing is harmless: what is left goes the next time.
  Future<void> pruneIfDue(DateTime now) async {
    if (_last case final last? when now.difference(last) < every) return;
    _last = now;
    await pruneBackupsAt(root, olderThan: now.subtract(backupRetention));
  }
}
