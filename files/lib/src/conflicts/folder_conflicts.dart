import 'package:meta/meta.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../listed_file.dart';

/// A pending conflict and the folder it is in.
@immutable
final class FolderConflict {
  const FolderConflict(this.folder, this.conflict);

  final Folder folder;
  final Conflict conflict;

  FileKey get key => (baseId: folder.base.id, path: conflict.mainPath);
}

/// The pending conflicts of all folders.
@immutable
final class FolderConflicts {
  const FolderConflicts(this.all);

  final List<FolderConflict> all;

  FolderConflict? forFile(FileKey key) {
    for (final conflict in all) {
      if (conflict.key == key) return conflict;
    }
    return null;
  }

  int countIn(String folderId) =>
      all.where((conflict) => conflict.folder.id == folderId).length;

  /// Conflicts whose main file is gone, shown as recoverable files.
  List<FolderConflict> get orphans =>
      all.where((conflict) => conflict.conflict.isOrphaned).toList();
}
