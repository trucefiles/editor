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
    required this.conflicts,
    required this.failedFolders,
    required this.startedAt,
  });

  /// Newest first.
  final List<Note> notes;

  final FolderConflicts conflicts;

  /// Folders that could not be scanned; they have no notes or conflicts.
  final Map<NoteFolder, StoreError> failedFolders;

  /// When the scan began; files written later may show older versions.
  final DateTime startedAt;

  Note? findNote(NoteKey key) {
    for (final note in notes) {
      if (note.key == key) return note;
    }
    return null;
  }
}
