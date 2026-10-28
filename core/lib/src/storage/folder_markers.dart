import 'dart:io';

/// A sync tool's only look outside a base folder's selection: whether the
/// base folder, or a folder above it, holds an entry of a given name (a
/// marker such as Syncthing's `.stfolder`). Asks for that name only, never
/// for what else a folder holds.
abstract interface class FolderMarkers {
  /// Whether the platform lets the app look at the folders above the base
  /// folder (not in a sandbox, for example).
  bool get seesParents;

  /// Whether the folder [levelsUp] above the base folder (0: the base
  /// folder itself) holds an entry named [name]; `null` if that folder
  /// can't be read, can't be seen, or lies above the file system root.
  Future<bool?> holds(String name, {int levelsUp = 0});
}

/// [FolderMarkers] of a base folder on the local file system, at the
/// absolute [basePath]. Symbolic links count as entries, never followed.
final class LocalFolderMarkers implements FolderMarkers {
  const LocalFolderMarkers(this.basePath, {required this.seesParents});

  final String basePath;

  @override
  final bool seesParents;

  @override
  Future<bool?> holds(String name, {int levelsUp = 0}) async {
    if (levelsUp > 0 && !seesParents) return null;
    final folder = _up(Directory(basePath).absolute, levelsUp);
    if (folder == null) return null;
    try {
      if (!await folder.exists()) return null;
      final entry = '${folder.path}${Platform.pathSeparator}$name';
      return await FileSystemEntity.type(entry, followLinks: false) !=
          FileSystemEntityType.notFound;
    } on FileSystemException {
      return null;
    }
  }

  /// The folder [levels] above [folder]; `null` above the root.
  static Directory? _up(Directory folder, int levels) {
    var current = folder;
    for (var level = 0; level < levels; level++) {
      final parent = current.parent;
      if (parent.path == current.path) return null;
      current = parent;
    }
    return current;
  }
}
