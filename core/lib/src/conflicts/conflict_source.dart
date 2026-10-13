import 'dart:typed_data';

import '../common/result.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import 'conflict.dart';

/// Where a sync tool keeps its conflicts. One implementation per sync tool.
///
/// Syncthing's finds conflict copies by file name next to the main file;
/// another tool may read its own metadata instead. Everything above sees
/// only neutral [Conflict]s.
abstract interface class ConflictSource {
  /// All pending conflicts in the folder, grouped by main file.
  Future<Result<List<Conflict>, StoreError>> find();

  /// Content of [copy]. Fails with [StoreError.changedSinceRead] if it
  /// changed since [find].
  Future<Result<Uint8List, StoreError>> read(ConflictCopy copy);

  /// Removes [copy] once it is resolved, with the same change check as
  /// [read].
  Future<Result<void, StoreError>> discard(ConflictCopy copy);

  /// Records [bytes] as a new conflict copy of [mainPath], the way the sync
  /// tool records its own, so it syncs and is resolved like one. For edits
  /// that cannot go into the main file.
  Future<Result<void, StoreError>> add(RelPath mainPath, Uint8List bytes);
}
