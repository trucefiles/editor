import 'package:flutter/material.dart';

import '../../common/snack.dart';
import '../checklist_editor.dart';

/// Shows [message] on [messenger] with an undo for the action of [editor]
/// that returned [undo]; tells if the checklist changed since.
void showChecklistUndoHint(
  ScaffoldMessengerState messenger,
  ChecklistEditor editor,
  String message,
  ChecklistUndo undo,
) => messenger.showHint(
  message,
  actionLabel: 'Undo',
  onAction: () {
    if (!editor.undo(undo)) {
      messenger.showHint("Can't undo: the note changed since.");
    }
  },
);
