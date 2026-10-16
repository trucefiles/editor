import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import '../common/moment.dart';
import '../conflicts/folder_conflicts.dart';
import '../folders/note_folder.dart';
import '../notes/note.dart';

/// What the last scan of all folders found.
@immutable
final class FolderScans {
  const FolderScans({
    required this.notes,
    required this.marks,
    required this.subfolders,
    required this.conflicts,
    required this.failedFolders,
    required this.startedAt,
  });

  /// Pinned first, then newest first.
  final List<Note> notes;

  /// Pins and colors; notes without a mark are left out.
  final Map<NoteKey, NoteMark> marks;

  /// Each folder's subfolders by folder id, sorted by path.
  final Map<String, List<RelPath>> subfolders;

  final FolderConflicts conflicts;

  /// Folders that could not be scanned; they have no notes or conflicts.
  final Map<NoteFolder, StoreError> failedFolders;

  /// When the scan began; files written later may show older versions.
  final Moment startedAt;

  NoteMark markOf(NoteKey key) => marks[key] ?? NoteMark.none;

  /// The subfolders of folder [folderId], empty ones too, sorted by path.
  List<RelPath> subfoldersOf(String folderId) =>
      subfolders[folderId] ?? const [];

  Note? findNote(NoteKey key) {
    for (final note in notes) {
      if (note.key == key) return note;
    }
    return null;
  }
}
