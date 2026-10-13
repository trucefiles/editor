import 'dart:io';

import 'sync_adapter.dart';

/// Whether the sync tool syncs a folder.
enum SyncCoverage {
  /// The folder or one of its parents is a root folder of the sync tool.
  synced,

  /// No root folder of the sync tool was found up to the top folder the
  /// app can read: changes likely stay on this device.
  notSynced,

  /// The parents cannot be read (e.g. in a sandbox), so the folder may be
  /// synced from a root above it.
  unknown,
}

/// Names of the entries in the folder at an absolute path; `null` if the
/// folder cannot be read.
typedef FolderNamesReader = Future<Set<String>?> Function(String folderPath);

/// Finds out whether a folder is synced by looking for the sync tool's root
/// marker in it and in its parents. Knows no sync tool itself; the
/// [SyncAdapter] names the marker.
final class SyncCoverageCheck {
  const SyncCoverageCheck(this._adapter, this._readNames);

  final SyncAdapter _adapter;
  final FolderNamesReader _readNames;

  /// Checks the folder at the absolute [folderPath]. Without
  /// [parentsVisible], only the folder itself is looked at.
  ///
  /// The walk up stops at the first parent that cannot be read: the sync
  /// tool's folders lie where apps can read.
  Future<SyncCoverage> check(
    String folderPath, {
    required bool parentsVisible,
  }) async {
    final folders = parentsVisible ? _withParents(folderPath) : [folderPath];
    for (final (index, folder) in folders.indexed) {
      final names = await _readNames(folder);
      if (names == null) {
        return index == 0 ? SyncCoverage.unknown : SyncCoverage.notSynced;
      }
      if (names.any(_adapter.marksSyncRoot)) return SyncCoverage.synced;
    }
    return parentsVisible ? SyncCoverage.notSynced : SyncCoverage.unknown;
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
