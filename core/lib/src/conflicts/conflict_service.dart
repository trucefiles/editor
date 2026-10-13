import 'dart:typed_data';

import '../common/result.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import 'conflict.dart';
import 'resolution.dart';

/// Finds and resolves conflicts in one folder. The app's only entry point
/// for conflicts.
///
/// Only orchestrates; never knows how a sync tool records conflicts. Built
/// from the folder's `FileStore`, the sync tool's `ConflictSource` and
/// backups in app storage. Phase 1 adds a `FileTypeDetector` and a map from
/// `FileType` to `ConflictHandler` for automatic merges; types without a
/// handler fall back to the user's choice.
abstract interface class ConflictService {
  /// All pending conflicts in the folder, grouped by main file.
  Future<Result<List<Conflict>, StoreError>> scan();

  /// Content of [copy], to show it to the user. Fails with
  /// [StoreError.changedSinceRead] if it changed since [scan].
  Future<Result<Uint8List, StoreError>> readCopy(ConflictCopy copy);

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

  /// Keeps [bytes] as a new conflict with [mainPath], e.g. edits that
  /// cannot be saved to it because it changed or was deleted elsewhere.
  Future<Result<void, StoreError>> keepAsConflict(
    RelPath mainPath,
    Uint8List bytes,
  );

  /// Deletes backups made by [resolve] before [olderThan].
  Future<Result<void, StoreError>> pruneBackups({required DateTime olderThan});
}

enum ResolveError { changedSinceScan, backupFailed, accessDenied, ioFailure }
