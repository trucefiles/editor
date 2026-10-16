import '../scan/folder_scans.dart';
import 'note_edit_session.dart';

/// The open note's view model: keeps its [session] in step with what
/// rescans find. No UI.
final class NoteEditorController {
  NoteEditorController(this.session);

  final NoteEditSession session;

  /// Hands what [scans] found for the note to the [session]. Skips scans
  /// that could not see the note (its folder failed, or a subfolder above
  /// it was unreadable): not finding it there says nothing about it.
  /// Returns `true` if the text was replaced by the latest file content.
  bool onScans(FolderScans scans) {
    final note = session.note;
    if (!scans.covers(note.key)) return false;
    return session.onRescan(
      scans.findNote(note.key),
      scannedAt: scans.startedAt,
    );
  }
}
