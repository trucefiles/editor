import 'dart:typed_data';

import '../common/result.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import 'backup.dart';

/// Copies of one folder's notes in app storage, so a change can be undone.
/// Never synced; only the user restores one.
final class NoteBackups {
  /// [ignores]: files in the store that are no backups, e.g. the temp
  /// files of atomic writes cut short.
  const NoteBackups(this._store, {this._ignores});

  final FileStore _store;
  final bool Function(RelPath file)? _ignores;

  /// Saves [bytes], the file at [notePath], before an editing session saves
  /// over it [at].
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
      final saved = await saveCurrent(
        at: at,
        notePath: notePath,
        bytes: current,
      );
      if (saved is Err) return saved;
    }
    return _save(Backup.of(notePath, at: at, kind: BackupKind.other), other);
  }

  /// Saves [bytes], the file at [notePath], before the user replaces it
  /// [at] with a version that is kept already (e.g. a backup restored).
  Future<Result<void, StoreError>> saveCurrent({
    required DateTime at,
    required RelPath notePath,
    required Uint8List bytes,
  }) => _save(Backup.of(notePath, at: at, kind: BackupKind.current), bytes);

  /// Every backup, newest first; none before the first one is saved.
  Future<Result<List<Backup>, StoreError>> list() async {
    final ignores = _ignores;
    final listed = await _store.list(
      includeFile: ignores == null ? null : (file) => !ignores(file),
    );
    switch (listed) {
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
      final savedAt = Backup.parse(entry.path)?.savedAt;
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
