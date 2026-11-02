import 'dart:io';

import '../common/result.dart';
import 'file_store.dart';
import 'rel_path.dart';

/// The names of the folders in a folder on a disk, e.g. so the user can
/// pick folders to add. Tells nothing else: no files, nothing deeper.
abstract interface class SubfolderNames {
  /// The names of the folders directly in [folder] (the top level
  /// if `null`), sorted.
  Future<Result<List<String>, StoreError>> namesIn(RelPath? folder);
}

/// Folder names as a plugin offers them to pick.
extension ShownSubfolderNames on SubfolderNames {
  /// Only the folders [shows] lets through, e.g. no hidden ones and none
  /// of the sync tool's own.
  SubfolderNames shownBy(bool Function(RelPath folder) shows) =>
      _Shown(this, shows);
}

final class _Shown implements SubfolderNames {
  const _Shown(this._all, this._shows);

  final SubfolderNames _all;
  final bool Function(RelPath folder) _shows;

  @override
  Future<Result<List<String>, StoreError>> namesIn(RelPath? folder) async =>
      switch (await _all.namesIn(folder)) {
        Ok(value: final names) => Ok([
          for (final name in names)
            if (_pathOf(folder, name) case final path? when _shows(path)) name,
        ]),
        Err(:final error) => Err(error),
      };

  static RelPath? _pathOf(RelPath? folder, String name) =>
      folder == null ? RelPath.parse(name) : folder.child(name);
}

/// [SubfolderNames] of a folder on the local file system, at the
/// absolute [folderPath]. Symbolic links are never followed, so they are no
/// folders here.
final class LocalSubfolderNames implements SubfolderNames {
  const LocalSubfolderNames(this.folderPath);

  final String folderPath;

  @override
  Future<Result<List<String>, StoreError>> namesIn(RelPath? folder) async {
    final path = folder == null
        ? folderPath
        : '$folderPath${Platform.pathSeparator}${folder.value}';
    try {
      final names = [
        await for (final entry in Directory(path).list(followLinks: false))
          if (entry is Directory) entry.uri.pathSegments.lastWhere(_named),
      ]..sort();
      return Ok(names);
    } on PathNotFoundException {
      return const Err(StoreError.notFound);
    } on PathAccessException {
      return const Err(StoreError.accessDenied);
    } on FileSystemException {
      return const Err(StoreError.ioFailure);
    }
  }

  static bool _named(String segment) => segment.isNotEmpty;
}
