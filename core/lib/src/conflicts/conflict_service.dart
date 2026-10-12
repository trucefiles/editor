import '../common/result.dart';
import '../storage/file_store.dart';
import 'conflict.dart';
import 'resolution.dart';

/// Finds and resolves conflicts in one folder. The app's only entry point
/// for conflicts.
///
/// Only orchestrates; never knows how a sync tool records conflicts. Built
/// from the folder's `FileStore`, the sync tool's `ConflictSource`, a backup
/// `FileStore` in app storage, a `FileTypeDetector`, and a map from
/// `FileType` to `ConflictHandler`. Types without a handler fall back to
/// the user's choice.
abstract interface class ConflictService {
  /// All pending conflicts in the folder, grouped by main file.
  Future<Result<List<Conflict>, StoreError>> scan();

  /// Applies [resolution] to [copy] of [conflict], in this order:
  /// 1. back up the main file and the copy in app storage;
  /// 2. write the chosen content to the main file (atomic);
  /// 3. have the `ConflictSource` discard the copy.
  ///
  /// Stops at the first failing step, so nothing is lost. Fails with
  /// [ResolveError.changedSinceScan] if either file changed since [scan].
  Future<Result<void, ResolveError>> resolve(
    Conflict conflict,
    ConflictCopy copy,
    Resolution resolution,
  );

  /// Deletes backups made by [resolve] before [olderThan].
  Future<Result<void, StoreError>> pruneBackups({required DateTime olderThan});
}

enum ResolveError { changedSinceScan, backupFailed, accessDenied, ioFailure }
