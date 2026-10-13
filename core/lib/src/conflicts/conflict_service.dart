import 'dart:typed_data';

import '../common/result.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import 'conflict.dart';
import 'resolution.dart';

/// Reads and resolves the conflicts of one folder, as found by its
/// `FolderScanner`. The app's only entry point for conflict content.
///
/// Only orchestrates; never knows how a sync tool records conflicts. Built
/// from the folder's `FileStore`, the sync tool's `ConflictSource` and
/// backups in app storage. Phase 1 adds a `FileTypeDetector` and a map from
/// `FileType` to `ConflictHandler` for automatic merges; types without a
/// handler fall back to the user's choice.
abstract interface class ConflictService {
  /// Content of [conflict]'s main file, to show it to the user. Fails with
  /// [StoreError.changedSinceRead] if it changed since the scan, and with
  /// [StoreError.notFound] if the conflict is orphaned.
  Future<Result<Uint8List, StoreError>> readMain(Conflict conflict);

  /// Content of [copy], to show it to the user. Fails with
  /// [StoreError.changedSinceRead] if it changed since the scan.
  Future<Result<Uint8List, StoreError>> readCopy(ConflictCopy copy);

  /// Applies [resolution] to [copy] of [conflict], in this order:
  /// 1. back up the main file and the copy in app storage;
  /// 2. write the chosen content to the main file (atomic);
  /// 3. have the `ConflictSource` discard the copy.
  ///
  /// Stops at the first failing step, so nothing is lost. Fails with
  /// [ResolveError.changedSinceScan] if either file changed since the scan.
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
}

enum ResolveError { changedSinceScan, backupFailed, accessDenied, ioFailure }
