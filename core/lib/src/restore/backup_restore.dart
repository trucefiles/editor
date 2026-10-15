import 'dart:typed_data';

import '../backups/backup.dart';
import '../backups/file_backups.dart';
import '../common/result.dart';
import '../storage/file_store.dart';
import '../versions/resolution.dart';
import '../versions/resolve_error.dart';

/// A backup next to its file as it is now, for the user to keep one.
final class RestoreChoice {
  const RestoreChoice(
    this.backup, {
    required this.bytes,
    required this.current,
  });

  final Backup backup;
  final Uint8List bytes;

  /// The file now; `null` if it is deleted.
  final FileContent? current;
}

/// Restores backups into one folder. The file a backup replaces is backed
/// up first; the backup itself stays as it is. Only the user restores.
final class BackupRestore {
  BackupRestore({
    required this._folder,
    required this._backups,
    this._clock = DateTime.now,
  });

  final FileStore _folder;
  final FileBackups _backups;
  final DateTime Function() _clock;

  /// [backup] and its file, to compare them.
  Future<Result<RestoreChoice, StoreError>> load(Backup backup) async {
    final Uint8List bytes;
    switch (await _backups.read(backup)) {
      case Ok(:final value):
        bytes = value;
      case Err(:final error):
        return Err(error);
    }
    return switch (await _folder.read(backup.filePath)) {
      Ok(:final value) => Ok(
        RestoreChoice(backup, bytes: bytes, current: value),
      ),
      Err(error: StoreError.notFound) => Ok(
        RestoreChoice(backup, bytes: bytes, current: null),
      ),
      Err(:final error) => Err(error),
    };
  }

  /// Keeps the file as it is ([KeepCurrent]: changes nothing) or
  /// puts the backup in its place ([KeepOther]), after a backup of the
  /// file. Fails with [ResolveError.changedSinceScan] if the file changed
  /// since [choice] was loaded.
  Future<Result<void, ResolveError>> keep(
    RestoreChoice choice,
    Resolution resolution,
  ) async {
    if (resolution is KeepCurrent) return const Ok(null);
    final path = choice.backup.filePath;
    final current = choice.current;
    if (current != null) {
      final backedUp = await _backups.saveCurrent(
        at: _clock(),
        filePath: path,
        bytes: current.bytes,
      );
      if (backedUp is Err) return const Err(ResolveError.backupFailed);
    }

    final written = switch (current) {
      null => await _folder.create(path, choice.bytes),
      final current => await _folder.replace(
        path,
        choice.bytes,
        ifUnchanged: current.version,
      ),
    };
    return switch (written) {
      Ok() => const Ok(null),
      // Creating fails so only if the folder itself is gone.
      Err(error: StoreError.notFound) when current == null => const Err(
        ResolveError.folderMissing,
      ),
      Err(:final error) => Err(ResolveError.ofStore(error)),
    };
  }
}
