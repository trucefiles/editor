import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import '../conflicts/folder_conflicts.dart';
import '../folders/note_folder.dart';
import '../notes/note.dart';

/// What the last scan of all folders found.
@immutable
final class FolderScans {
  const FolderScans({
    required this.notes,
    required this.marks,
    required this.conflicts,
    required this.failedFolders,
    required this.startedAt,
  });

  /// Pinned first, then newest first.
  final List<Note> notes;

  /// Pins and colors; notes without a mark are left out.
  final Map<NoteKey, NoteMark> marks;

  final FolderConflicts conflicts;

  /// Folders that could not be scanned; they have no notes or conflicts.
  final Map<NoteFolder, StoreError> failedFolders;

  /// When the scan began; files written later may show older versions.
  final DateTime startedAt;

  NoteMark markOf(NoteKey key) => marks[key] ?? NoteMark.none;

  /// The subfolders of folder [folderId] that hold notes, directly or
  /// deeper, sorted by path. Empty subfolders are not scanned, so they are
  /// left out.
  List<RelPath> subfoldersOf(String folderId) {
    final found = <RelPath>{};
    for (final note in notes.where((note) => note.folder.id == folderId)) {
      for (var folder = note.path.parent; folder != null;) {
        if (!found.add(folder)) break;
        folder = folder.parent;
      }
    }
    return found.toList()..sort((a, b) => a.value.compareTo(b.value));
  }

  Note? findNote(NoteKey key) {
    for (final note in notes) {
      if (note.key == key) return note;
    }
    return null;
  }
}
