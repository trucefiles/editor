import 'dart:typed_data';

import '../common/result.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import 'backup.dart';

/// Copies of one folder's files in app storage, so a change can be undone.
/// Never synced; only the user restores one.
final class FileBackups {
  /// [ignores]: files in the store that are no backups, e.g. the temp
  /// files of atomic writes cut short.
  const FileBackups(this._store, {this._ignores});

  final FileStore _store;
  final bool Function(RelPath file)? _ignores;

  /// Saves [bytes], the file at [filePath], before an editing session saves
  /// over it [at].
  Future<Result<void, StoreError>> saveBeforeEdit({
    required DateTime at,
    required RelPath filePath,
    required Uint8List bytes,
  }) => _save(Backup.of(filePath, at: at, kind: BackupKind.beforeEdit), bytes);

  /// Saves both versions the user picks from [at], before keeping one.
  /// [current] is `null` if the file is deleted.
  Future<Result<void, StoreError>> saveBoth({
    required DateTime at,
    required RelPath filePath,
    required Uint8List? current,
    required Uint8List other,
  }) async {
    if (current != null) {
      final saved = await saveCurrent(
        at: at,
        filePath: filePath,
        bytes: current,
      );
      if (saved is Err) return saved;
    }
    return _save(Backup.of(filePath, at: at, kind: BackupKind.other), other);
  }

  /// Saves [bytes], the file at [filePath], before the user replaces it
  /// [at] with a version that is kept already (e.g. a backup restored).
  Future<Result<void, StoreError>> saveCurrent({
    required DateTime at,
    required RelPath filePath,
    required Uint8List bytes,
  }) => _save(Backup.of(filePath, at: at, kind: BackupKind.current), bytes);

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

  /// The backups of the file at [filePath], newest first.
  Future<Result<List<Backup>, StoreError>> listOf(RelPath filePath) async =>
      switch (await list()) {
        Ok(:final value) => Ok([
          for (final backup in value)
            if (backup.filePath == filePath) backup,
        ]),
        Err(:final error) => Err(error),
      };

  Future<Result<Uint8List, StoreError>> read(Backup backup) async =>
      switch (await _store.read(backup.storePath)) {
        Ok(:final value) => Ok(value.bytes),
        Err(:final error) => Err(error),
      };

  /// Deletes [backup]; the user asked for it.
  Future<Result<void, StoreError>> delete(Backup backup) async =>
      switch (await _store.read(backup.storePath)) {
        Ok(:final value) => await _store.delete(
          backup.storePath,
          ifUnchanged: value.version,
        ),
        Err(:final error) => Err(error),
      };

  /// Moves the backups of [from] to [into] (this store or another
  /// folder's), as backups of [to], each keeping its time and kind: the
  /// document moved or was renamed. Each one is saved there before it is
  /// deleted here, so a failure leaves it in one place or both, never in
  /// none. Stops at the first failure.
  Future<Result<void, StoreError>> moveAll({
    required RelPath from,
    required RelPath to,
    required FileBackups into,
  }) async {
    final List<Backup> moving;
    switch (await listOf(from)) {
      case Ok(:final value):
        moving = value;
      case Err(:final error):
        return Err(error);
    }
    for (final backup in moving) {
      final moved = await _moveOne(backup, to, into);
      if (moved is Err) return moved;
    }
    return const Ok(null);
  }

  Future<Result<void, StoreError>> _moveOne(
    Backup backup,
    RelPath to,
    FileBackups into,
  ) async {
    final FileContent content;
    switch (await _store.read(backup.storePath)) {
      case Ok(:final value):
        content = value;
      case Err(:final error):
        return Err(error);
    }
    final saved = await into._save(
      Backup.of(to, at: backup.savedAt, kind: backup.kind),
      content.bytes,
    );
    if (saved is Err) return saved;
    return _store.delete(backup.storePath, ifUnchanged: content.version);
  }

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

  /// Saves [backup]; where one of the same file and kind was saved in the
  /// same microsecond, at the next free one, so neither is lost.
  Future<Result<void, StoreError>> _save(
    Backup backup,
    Uint8List bytes,
  ) async => switch (await _store.create(backup.storePath, bytes)) {
    Ok() => const Ok(null),
    Err(error: StoreError.alreadyExists) => _save(
      Backup.of(
        backup.filePath,
        at: backup.savedAt.add(const Duration(microseconds: 1)),
        kind: backup.kind,
      ),
      bytes,
    ),
    Err(:final error) => Err(error),
  };
}
