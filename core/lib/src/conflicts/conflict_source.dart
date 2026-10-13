import 'dart:typed_data';

import '../common/result.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import 'conflict.dart';

/// Where a sync tool keeps its conflict copies. One implementation per
/// sync tool.
///
/// Syncthing keeps them as files next to the main file; another tool may
/// keep them in its own metadata. Finding them is part of the sync tool's
/// `FolderScanner`.
abstract interface class ConflictSource {
  /// Content of [copy]. Fails with [StoreError.changedSinceRead] if it
  /// changed since it was scanned.
  Future<Result<Uint8List, StoreError>> read(ConflictCopy copy);

  /// Removes [copy] once it is resolved, with the same change check as
  /// [read].
  Future<Result<void, StoreError>> discard(ConflictCopy copy);

  /// Records [bytes] as a new conflict copy of [mainPath], the way the sync
  /// tool records its own, so it syncs and is resolved like one. For edits
  /// that cannot go into the main file.
  Future<Result<void, StoreError>> add(RelPath mainPath, Uint8List bytes);
}
