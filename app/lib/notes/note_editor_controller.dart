import '../scan/folder_scans.dart';
import 'note_edit_session.dart';

/// The open note's view model: keeps its [session] in step with what
/// rescans find. No UI.
final class NoteEditorController {
  NoteEditorController(this.session);

  final NoteEditSession session;

  /// Hands what [scans] found for the note to the [session]. Skips scans
  /// in which the note's folder failed: they found no notes there, which
  /// says nothing about the note. Returns `true` if the text was replaced
  /// by the latest file content.
  bool onScans(FolderScans scans) {
    final note = session.note;
    final folderFailed = scans.failedFolders.keys.any(
      (folder) => folder.id == note.folder.id,
    );
    if (folderFailed) return false;
    return session.onRescan(
      scans.findNote(note.key),
      scannedAt: scans.startedAt,
    );
  }
}
