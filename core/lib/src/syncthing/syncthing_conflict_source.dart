import 'dart:typed_data';

import '../common/result.dart';
import '../conflicts/conflict.dart';
import '../conflicts/conflict_source.dart';
import '../filter/file_filter.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import 'syncthing_conflict_name.dart';

/// Finds Syncthing's conflict copies by name, next to their main file.
///
/// Only conflicts whose main file the [FileFilter] includes are found, in
/// the folders it lets through. A copy's id is its path.
final class SyncthingConflictSource implements ConflictSource {
  const SyncthingConflictSource(this._store, this._filter);

  final FileStore _store;
  final FileFilter _filter;

  @override
  Future<Result<List<Conflict>, StoreError>> find() async {
    final listed = await _store.list(enterFolder: _filter.includesFolder);
    return switch (listed) {
      Ok(value: final entries) => Ok(_group(entries)),
      Err(:final error) => Err(error),
    };
  }

  @override
  Future<Result<Uint8List, StoreError>> read(ConflictCopy copy) async {
    final read = await _store.read(_path(copy));
    return switch (read) {
      Ok(value: final content) when content.stamp != copy.stamp => const Err(
        StoreError.changedSinceRead,
      ),
      Ok(value: final content) => Ok(content.bytes),
      Err(:final error) => Err(error),
    };
  }

  @override
  Future<Result<void, StoreError>> discard(ConflictCopy copy) =>
      _store.delete(_path(copy), ifUnchanged: copy.stamp);

  List<Conflict> _group(List<FileEntry> entries) {
    final stamps = {for (final e in entries) e.path: e.stamp};
    final copiesByMain = <RelPath, List<ConflictCopy>>{};
    for (final entry in entries) {
      final name = SyncthingConflictName.parse(entry.path.name);
      if (name == null) continue;
      final mainPath = entry.path.sibling(name.mainName);
      if (mainPath == null || !_filter.includesFile(mainPath)) continue;
      copiesByMain
          .putIfAbsent(mainPath, () => [])
          .add(
            ConflictCopy(
              id: entry.path.value,
              stamp: entry.stamp,
              createdAt: name.createdAt,
            ),
          );
    }
    return [
      for (final MapEntry(key: mainPath, value: copies) in copiesByMain.entries)
        Conflict(
          mainPath: mainPath,
          mainStamp: stamps[mainPath],
          // File-name order: the timestamps in the names sort oldest first.
          copies: copies..sort((a, b) => a.id.compareTo(b.id)),
        ),
    ];
  }

  /// Ids are paths made by [find], so they always parse.
  RelPath _path(ConflictCopy copy) => RelPath.parse(copy.id)!;
}
