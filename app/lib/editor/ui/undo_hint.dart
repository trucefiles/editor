import 'package:flutter/material.dart';

import '../../common/snack.dart';
import '../note_document_controller.dart';

/// Shows [message] on [messenger] with an undo for the action of [note]
/// that returned [undo]; tells if the note changed since.
void showUndoHint(
  ScaffoldMessengerState messenger,
  NoteDocumentController note,
  String message,
  EditUndo undo,
) => messenger.showHint(
  message,
  actionLabel: 'Undo',
  onAction: () {
    if (!note.undo(undo)) {
      messenger.showHint("Can't undo: the note changed since.");
    }
  },
);
