import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/note_folder.dart';
import '../notes/note.dart';

/// A pending conflict and the folder it is in.
@immutable
final class FolderConflict {
  const FolderConflict(this.folder, this.conflict);

  final NoteFolder folder;
  final Conflict conflict;

  NoteKey get key => (folderId: folder.id, path: conflict.mainPath);
}

/// The pending conflicts of all folders.
@immutable
final class FolderConflicts {
  const FolderConflicts(this.all);

  final List<FolderConflict> all;

  FolderConflict? forNote(NoteKey key) {
    for (final conflict in all) {
      if (conflict.key == key) return conflict;
    }
    return null;
  }

  int countIn(String folderId) =>
      all.where((conflict) => conflict.folder.id == folderId).length;

  /// Conflicts whose main file is gone, shown as recoverable notes.
  List<FolderConflict> get orphans =>
      all.where((conflict) => conflict.conflict.isOrphaned).toList();
}
