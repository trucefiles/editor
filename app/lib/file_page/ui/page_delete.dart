import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../../common/snack.dart';
import '../../common/store_error_text.dart';
import '../../files/file_actions.dart';
import '../../files/ui/delete_failure_text.dart';
import '../text_edit_page_controller.dart';

/// Tells how deleting the open file went, on its page [screen]: the page
/// closes once the file is gone, with Undo on [appMessenger], which
/// outlives the page; a refused delete says why.
void tellDeleted(
  BuildContext screen,
  DeleteOutcome outcome, {
  required ScaffoldMessengerState appMessenger,
  required FileActions actions,
}) {
  switch (outcome) {
    case NewDropped():
      Navigator.pop(screen);
    case DeletedForUndo(:final deleted):
      _offerUndo(appMessenger, actions, deleted);
      Navigator.pop(screen);
    case DeleteRefused(:final failure):
      showSnack(screen, deleteFailureText(failure));
    case AlreadyGone() || FileStopped():
      break;
  }
}

void _offerUndo(
  ScaffoldMessengerState messenger,
  FileActions actions,
  UndoableDelete deleted,
) => messenger.showHint(
  'File deleted',
  actionLabel: 'Undo',
  onAction: () async {
    if (await actions.undoDelete(deleted) case Err(:final error)) {
      messenger.showHint(error.text);
    }
  },
);
