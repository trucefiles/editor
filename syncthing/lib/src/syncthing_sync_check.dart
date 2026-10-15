import 'dart:io';

import 'package:truce_core/truce_core.dart';

/// Checks a folder for Syncthing's `.stfolder` marker, which Syncthing
/// creates in the root of every folder it syncs: the folder is synced if
/// it or one of its parents has one.
final class SyncthingSyncCheck implements SyncCheck {
  /// [_folderPath] is the folder's absolute path. [_parentsVisible] tells
  /// whether the platform lets the app read the folder's parents (not in a
  /// sandbox, for example).
  const SyncthingSyncCheck(
    this._folderPath, {
    required this._readNames,
    required this._parentsVisible,
  });

  static const _rootMarker = '.stfolder';

  final String _folderPath;
  final FolderNamesReader _readNames;
  final bool _parentsVisible;

  /// Walks up to the file system root, and stops at the first parent it
  /// cannot read: Syncthing folders lie where apps can read. Where parents
  /// are hidden, looks only at the folder itself.
  @override
  Future<SyncStatus> check() async {
    final folders = _parentsVisible ? _withParents(_folderPath) : [_folderPath];
    for (final (index, folder) in folders.indexed) {
      final names = await _readNames(folder);
      if (names == null) {
        return index == 0 ? SyncStatus.unknown : SyncStatus.notSynced;
      }
      if (names.contains(_rootMarker)) return SyncStatus.synced;
    }
    return _parentsVisible ? SyncStatus.notSynced : SyncStatus.unknown;
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
