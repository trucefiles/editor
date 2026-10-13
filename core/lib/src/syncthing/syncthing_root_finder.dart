import 'dart:io';

import '../storage/folder_names.dart';
import '../sync/sync_root_finder.dart';

/// Finds a Syncthing folder's root by its `.stfolder` marker, which
/// Syncthing creates in every root it syncs.
final class SyncthingRootFinder implements SyncRootFinder {
  const SyncthingRootFinder(this._readNames);

  static const _rootMarker = '.stfolder';

  final FolderNamesReader _readNames;

  /// Walks up to the file system root, and stops at the first parent it
  /// cannot read: Syncthing folders lie where apps can read.
  @override
  Future<SyncRootSearch> find(
    String folderPath, {
    required bool parentsVisible,
  }) async {
    final folders = parentsVisible ? _withParents(folderPath) : [folderPath];
    for (final (index, folder) in folders.indexed) {
      final names = await _readNames(folder);
      if (names == null) {
        return index == 0 ? const SyncRootUnknown() : const SyncRootMissing();
      }
      if (names.contains(_rootMarker)) return SyncRootFound(folder);
    }
    return parentsVisible ? const SyncRootMissing() : const SyncRootUnknown();
  }

  /// [folderPath], then each parent up to the file system root.
  static List<String> _withParents(String folderPath) {
    final folders = <String>[];
    var folder = Directory(folderPath).absolute;
    while (true) {
      folders.add(folder.path);
      final parent = folder.parent;
      if (parent.path == folder.path) return folders;
      folder = parent;
    }
  }
}
