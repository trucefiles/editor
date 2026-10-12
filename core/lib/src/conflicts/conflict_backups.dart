import 'dart:typed_data';

import '../common/result.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';

/// Copies of conflict inputs in app storage, so a resolution can be undone.
///
/// One flat folder; a file per input, named
/// `<time in µs since epoch>.<side>.<main path, URI-encoded>`, e.g.
/// `1791818275000000.other.lists%2Ftodo.md`.
final class ConflictBackups {
  const ConflictBackups(this._store);

  final FileStore _store;

  /// Saves the inputs of one resolution made [at]. [current] is `null` for
  /// an orphaned conflict.
  Future<Result<void, StoreError>> save({
    required DateTime at,
    required RelPath mainPath,
    required Uint8List? current,
    required Uint8List other,
  }) async {
    if (current != null) {
      final saved = await _save(at, 'current', mainPath, current);
      if (saved is Err) return saved;
    }
    return _save(at, 'other', mainPath, other);
  }

  /// Deletes backups saved before [olderThan]. Stops at the first failure.
  Future<Result<void, StoreError>> prune({required DateTime olderThan}) async {
    final List<FileEntry> entries;
    switch (await _store.list()) {
      case Ok(:final value):
        entries = value;
      case Err(:final error):
        return Err(error);
    }
    for (final entry in entries) {
      final savedAt = _savedAt(entry.path);
      if (savedAt == null || !savedAt.isBefore(olderThan)) continue;
      final deleted = await _store.delete(entry.path, ifUnchanged: entry.stamp);
      if (deleted is Err) return deleted;
    }
    return const Ok(null);
  }

  Future<Result<void, StoreError>> _save(
    DateTime at,
    String side,
    RelPath mainPath,
    Uint8List bytes,
  ) async {
    final name =
        '${at.microsecondsSinceEpoch}.$side.'
        '${Uri.encodeComponent(mainPath.value)}';
    final created = await _store.create(RelPath.parse(name)!, bytes);
    return switch (created) {
      Ok() => const Ok(null),
      Err(:final error) => Err(error),
    };
  }

  /// When the backup at [path] was saved; `null` if it is not a backup.
  static DateTime? _savedAt(RelPath path) {
    final micros = int.tryParse(path.value.split('.').first);
    return micros == null
        ? null
        : DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
  }
}
