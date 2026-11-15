import 'package:collection/collection.dart';

import 'backup.dart';

/// A backup kept in one of the app's backup folders ([folder], e.g. its
/// path), with its [size] in bytes.
typedef SizedBackup<F> = ({F folder, Backup backup, int size});

/// The backups to delete, in order, so that [backups] take at most
/// [limit] bytes: each time the oldest backup of the file whose backups
/// take the most space (a file is a path in a folder), so a large file
/// gives up its own history first. A file's newest backups (those saved
/// together at its latest moment, e.g. both sides of a kept conflict)
/// are never among them, so the rest may stay over [limit].
List<SizedBackup<F>> overSpaceLimit<F>(
  Iterable<SizedBackup<F>> backups,
  int limit,
) {
  final files = groupBy(
    backups,
    (b) => (b.folder, b.backup.filePath),
  ).values.map(_FileHistory<F>.new).where((file) => file.canGiveUp);
  final largestFirst = PriorityQueue<_FileHistory<F>>(
    (a, b) => b.size.compareTo(a.size),
  )..addAll(files);
  var total = backups.map((b) => b.size).sum;
  final deleted = <SizedBackup<F>>[];
  while (total > limit && largestFirst.isNotEmpty) {
    final file = largestFirst.removeFirst();
    final oldest = file.giveUpOldest();
    deleted.add(oldest);
    total -= oldest.size;
    if (file.canGiveUp) largestFirst.add(file);
  }
  return deleted;
}

/// One file's backups, as they are given up, oldest first: all but its
/// newest, those saved at its latest moment.
final class _FileHistory<F> {
  _FileHistory(Iterable<SizedBackup<F>> backups)
    : _older = _olderThanNewest(backups),
      size = backups.map((b) => b.size).sum;

  final List<SizedBackup<F>> _older;
  int _given = 0;

  /// The space its backups left take.
  int size;

  /// Whether it has a backup left to give up.
  bool get canGiveUp => _given < _older.length;

  SizedBackup<F> giveUpOldest() {
    final oldest = _older[_given++];
    size -= oldest.size;
    return oldest;
  }

  /// [backups] saved before the latest of them, oldest first.
  static List<SizedBackup<F>> _olderThanNewest<F>(
    Iterable<SizedBackup<F>> backups,
  ) {
    final newest = backups.map((b) => b.backup.savedAt).max;
    return backups
        .where((b) => b.backup.savedAt.isBefore(newest))
        .sortedBy((b) => b.backup.savedAt);
  }
}
