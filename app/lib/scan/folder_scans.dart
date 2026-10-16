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
    required this.unreadable,
    required this.startedAt,
    this.unreadNotes = const {},
  });

  /// Newest first.
  final List<Note> notes;

  /// Colors; notes without a mark are left out.
  final Map<NoteKey, NoteMark> marks;

  /// Each folder's subfolders by folder id, sorted by path.
  final Map<String, List<RelPath>> subfolders;

  final FolderConflicts conflicts;

  /// Folders that could not be scanned; they have no notes or conflicts.
  final Map<NoteFolder, StoreError> failedFolders;

  /// Each folder's subfolders that could not be read, by folder id; only
  /// folders that have some.
  final Map<String, List<RelPath>> unreadable;

  /// When the scan began; files written later may show older versions.
  final Moment startedAt;

  /// Notes whose files were listed but could not be read in their current
  /// version (e.g. no access for a moment, no longer text, gone right
  /// after the listing): [notes] holds their last version, if any.
  final Set<NoteKey> unreadNotes;

  NoteMark markOf(NoteKey key) => marks[key] ?? NoteMark.none;

  /// The subfolders of folder [folderId], empty ones too, sorted by path.
  List<RelPath> subfoldersOf(String folderId) =>
      subfolders[folderId] ?? const [];

  /// Whether this scan could see the note at [key] as it is, if it exists:
  /// its folder was scanned, no subfolder above it was unreadable, and its
  /// file was read. If not, a note missing from [notes] may still exist,
  /// and one in [notes] may be older than its file.
  bool covers(NoteKey key) =>
      !unreadNotes.contains(key) &&
      !failedFolders.keys.any((folder) => folder.id == key.folderId) &&
      !(unreadable[key.folderId] ?? const []).any(
        (folder) => key.path.value.startsWith('${folder.value}/'),
      );

  Note? findNote(NoteKey key) {
    for (final note in notes) {
      if (note.key == key) return note;
    }
    return null;
  }
}
