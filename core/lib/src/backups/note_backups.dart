import 'dart:typed_data';

import '../common/result.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import 'backup.dart';

/// Copies of one folder's notes in app storage, so a change can be undone.
/// Never synced; only the user restores one.
final class NoteBackups {
  const NoteBackups(this._store);

  final FileStore _store;

  /// Saves [bytes], the file at [notePath], before the first save of an
  /// editing session made [at].
  Future<Result<void, StoreError>> saveBeforeEdit({
    required DateTime at,
    required RelPath notePath,
    required Uint8List bytes,
  }) => _save(Backup.of(notePath, at: at, kind: BackupKind.beforeEdit), bytes);

  /// Saves both versions the user picks from [at], before keeping one.
  /// [current] is `null` if the note's file is deleted.
  Future<Result<void, StoreError>> saveBoth({
    required DateTime at,
    required RelPath notePath,
    required Uint8List? current,
    required Uint8List other,
  }) async {
    if (current != null) {
      final saved = await _save(
        Backup.of(notePath, at: at, kind: BackupKind.current),
        current,
      );
      if (saved is Err) return saved;
    }
    return _save(Backup.of(notePath, at: at, kind: BackupKind.other), other);
  }

  /// Every backup, newest first; none before the first one is saved.
  Future<Result<List<Backup>, StoreError>> list() async {
    switch (await _store.list()) {
      case Ok(:final value):
        final backups = [
          for (final entry in value.files) ?Backup.parse(entry.path),
        ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
        return Ok(backups);
      case Err(error: StoreError.notFound):
        return const Ok([]);
      case Err(:final error):
        return Err(error);
    }
  }

  Future<Result<Uint8List, StoreError>> read(Backup backup) async =>
      switch (await _store.read(backup.storePath)) {
        Ok(:final value) => Ok(value.bytes),
        Err(:final error) => Err(error),
      };

  /// Deletes backups saved before [olderThan]. Stops at the first failure.
  Future<Result<void, StoreError>> prune({required DateTime olderThan}) async {
    final List<FileEntry> entries;
    switch (await _store.list()) {
      case Ok(:final value):
        entries = value.files;
      case Err(error: StoreError.notFound):
        return const Ok(null);
      case Err(:final error):
        return Err(error);
    }
    for (final entry in entries) {
      final savedAt = Backup.savedAtOf(entry.path);
      if (savedAt == null || !savedAt.isBefore(olderThan)) continue;
      final deleted = await _store.delete(
        entry.path,
        ifUnchanged: entry.version,
      );
      if (deleted is Err) return deleted;
    }
    return const Ok(null);
  }

  Future<Result<void, StoreError>> _save(
    Backup backup,
    Uint8List bytes,
  ) async => switch (await _store.create(backup.storePath, bytes)) {
    Ok() => const Ok(null),
    Err(:final error) => Err(error),
  };
}
