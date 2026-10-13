import 'dart:io';

import '../storage/folder_names.dart';
import '../sync/sync_root_finder.dart';

/// Finds a Syncthing folder's root by its `.stfolder` marker, which
/// Syncthing creates in every root it syncs.
final class SyncthingRootFinder implements SyncRootFinder {
  /// [canReadParents] tells whether the platform lets the app read the
  /// parent folders of a folder (not in a sandbox, for example).
  const SyncthingRootFinder(
    this._readNames, {
    required bool Function(String folderPath) canReadParents,
  }) : _canReadParents = canReadParents;

  static const _rootMarker = '.stfolder';

  final FolderNamesReader _readNames;
  final bool Function(String folderPath) _canReadParents;

  /// Walks up to the file system root, and stops at the first parent it
  /// cannot read: Syncthing folders lie where apps can read. Where parents
  /// are hidden, looks only at the folder itself.
  @override
  Future<SyncRootSearch> find(String folderPath) async {
    final parentsVisible = _canReadParents(folderPath);
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
