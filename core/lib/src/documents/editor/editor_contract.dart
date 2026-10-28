/// What every document type's editor owner shares with the document page:
/// the requests the page sends it, the notices it gives the page, and
/// what its state tells of the edits. One editor owner per open
/// document; it holds what the editor shows, runs the type's edits, and
/// sends the text to the file owner as the save timing says (see
/// `save_clock.dart`).
library;

import '../../owners/ask.dart';
import '../../owners/owner.dart';
import '../file_owner/file_contract.dart';

/// Any document type's editor owner as the document page sees it: the
/// page's requests go in, its notices come out, and its state tells of
/// the edits.
typedef PageEditor = Owner<EditorRequest, EditorStatus, EditorNotice>;

/// What the document page asks of any editor.
sealed class EditorRequest {
  const EditorRequest();
}

/// What the file owner tells the editor.
final class FromFile extends EditorRequest {
  const FromFile(this.message);

  final ToEditor message;
}

/// Keep the edits somewhere lasting now (the user leaves, hides or
/// closes): the editor sends its text, then asks the file owner to keep
/// it; the file owner's answer carries [ticket] back.
final class SecureEditor extends EditorRequest implements Asking {
  const SecureEditor(this.ticket, this.reason);

  @override
  final Ticket ticket;
  final SecureReason reason;
}

/// Undo the latest step of this editing session.
final class Undo extends EditorRequest {
  const Undo();
}

/// Redo the step undone last.
final class Redo extends EditorRequest {
  const Redo();
}

/// Undo step [id], which [UndoOffered] told of, if it is still the
/// latest.
final class UndoStep extends EditorRequest {
  const UndoStep(this.id);

  final int id;
}

/// The document now reads [text] (a backup the user restored): one step,
/// which undo takes back.
final class ReplaceAll extends EditorRequest {
  const ReplaceAll(this.text);

  final String text;
}

/// What any editor tells the document page.
sealed class EditorNotice {
  const EditorNotice();
}

/// What the file owner gets.
final class ToFile extends EditorNotice {
  const ToFile(this.input);

  final FileInput input;
}

/// Undo step [id] is one the user is offered to undo right away: [what]
/// it did.
final class UndoOffered extends EditorNotice {
  const UndoOffered(this.id, this.what);

  final int id;
  final OfferedUndo what;
}

/// What a step offered for undo did.
enum OfferedUndo {
  /// Removed items, or blocks without text.
  removal,

  /// Put a backup in place of the text ([ReplaceAll]).
  restore,
}

/// Undo step [id] could not be undone: the text changed since.
final class UndoRefused extends EditorNotice {
  const UndoRefused(this.id);

  final int id;
}

/// Undo reached the start of the history, which is there for [start].
final class HistoryEnd extends EditorNotice {
  const HistoryEnd(this.start);

  final HistoryStart start;
}

/// Why the undo history starts where it does.
enum HistoryStart {
  /// The document was opened there.
  opened,

  /// The document changed on another device (or elsewhere) there.
  changedElsewhere,

  /// A version was picked, or edits discarded, there.
  replacedHere,

  /// Older steps are not kept.
  limit,
}

/// What any editor's state tells of the edits.
final class EditorStatus {
  const EditorStatus({
    this.unsent = false,
    this.canUndo = false,
    this.canRedo = false,
  });

  /// Whether there are edits only in memory, not yet sent to be kept.
  final bool unsent;

  /// Whether [Undo] and [Redo] have a step to take.
  final bool canUndo;
  final bool canRedo;

  @override
  bool operator ==(Object other) =>
      other is EditorStatus &&
      other.unsent == unsent &&
      other.canUndo == canUndo &&
      other.canRedo == canRedo;

  @override
  int get hashCode => Object.hash(unsent, canUndo, canRedo);
}
