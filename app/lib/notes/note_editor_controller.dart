import 'package:truce_core/truce_core.dart';

import '../scan/folder_scans.dart';
import 'open_note.dart';

/// The open note's view model: keeps it in step with what rescans find,
/// and tells whether its edits are kept. No UI.
final class NoteEditorController {
  /// [reachSettled]: the reach of the note's folder once a running check
  /// of it is over.
  NoteEditorController(this.note, {required this.reachSettled});

  final OpenNote note;
  final Future<Reach> Function() reachSettled;

  /// Keeps the edits ([OpenNote.secure]); whether they are kept: in the
  /// file or a conflict copy, or on this device while the folder can't be
  /// reached. A failed save may just have started a check of the folder,
  /// so this waits for its outcome.
  Future<bool> keep() async {
    if (await note.secure()) return true;
    return await reachSettled() == Reach.unreachable;
  }

  /// Hands what [scans] found for the note to its session; a new note has
  /// no file to find yet. Skips scans that could not see the note (its
  /// folder failed, or a subfolder above it was unreadable): not finding
  /// it there says nothing about it. Returns `true` if the text was
  /// replaced by the latest file content.
  bool onScans(FolderScans scans) {
    final session = note.session;
    if (session == null) return false;
    final key = session.note.key;
    if (!scans.covers(key)) return false;
    return session.onRescan(scans.findNote(key), scannedAt: scans.startedAt);
  }
}
