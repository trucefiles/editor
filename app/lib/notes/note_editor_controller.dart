import 'package:truce_core/truce_core.dart';

import '../scan/folder_scans.dart';
import 'note_edit_session.dart';

/// The open note's view model: keeps its [session] in step with what
/// rescans find, and tells whether its edits are kept. No UI.
final class NoteEditorController {
  /// [reachSettled]: the reach of the note's folder once a running check
  /// of it is over.
  NoteEditorController(this.session, {required this.reachSettled});

  final NoteEditSession session;
  final Future<Reach> Function() reachSettled;

  /// Keeps the edits ([NoteEditSession.secure]); whether they are kept:
  /// in the file or a conflict copy, or on this device while the folder
  /// can't be reached. A failed save may just have started a check of the
  /// folder, so this waits for its outcome.
  Future<bool> keep() async {
    if (await session.secure()) return true;
    return await reachSettled() == Reach.unreachable;
  }

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
