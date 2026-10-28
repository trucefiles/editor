import 'dart:io';

import '../common/result.dart';
import '../filter/file_filter.dart';
import 'file_store.dart';
import 'rel_path.dart';

/// The names of the folders in a folder of a base folder, so the user can
/// pick which subfolders a folder shows. Tells nothing else: no files,
/// nothing deeper.
abstract interface class SubfolderNames {
  /// The names of the folders directly in [folder] (the base folder
  /// itself if `null`), sorted.
  Future<Result<List<String>, StoreError>> namesIn(RelPath? folder);
}

/// Subfolder names as a sync tool offers them to pick.
extension ShownSubfolderNames on SubfolderNames {
  /// Only the folders [shown] lets through, e.g. no hidden ones and none
  /// of the tool's own.
  SubfolderNames shownBy(FileFilter shown) => _Shown(this, shown);
}

final class _Shown implements SubfolderNames {
  const _Shown(this._all, this._shown);

  final SubfolderNames _all;
  final FileFilter _shown;

  @override
  Future<Result<List<String>, StoreError>> namesIn(RelPath? folder) async =>
      switch (await _all.namesIn(folder)) {
        Ok(value: final names) => Ok([
          for (final name in names)
            if (_pathOf(folder, name) case final path?
                when _shown.includesFolder(path))
              name,
        ]),
        Err(:final error) => Err(error),
      };

  static RelPath? _pathOf(RelPath? folder, String name) =>
      folder == null ? RelPath.parse(name) : folder.child(name);
}

/// [SubfolderNames] of a base folder on the local file system, at the
/// absolute [basePath]. Symbolic links are never followed, so they are no
/// folders here.
final class LocalSubfolderNames implements SubfolderNames {
  const LocalSubfolderNames(this.basePath);

  final String basePath;

  @override
  Future<Result<List<String>, StoreError>> namesIn(RelPath? folder) async {
    final path = folder == null
        ? basePath
        : '$basePath${Platform.pathSeparator}${folder.value}';
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
