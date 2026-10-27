import 'package:flutter/material.dart';

import '../../backups/all_backups.dart';
import '../../backups/ui/document_backups_screen.dart';
import '../../backups/ui/restore_into_document_screen.dart';
import '../../common/snack.dart';
import '../../documents/document.dart';
import '../document_controller.dart';

/// Opens the backups of the open [document], whose title is [title];
/// restoring one goes through [controller], into the document (while it
/// can be edited), and comes back to it; the editor offers its undo.
/// [messenger] is the document screen's, to tell a failure there.
Future<void> openDocumentBackups(
  BuildContext context, {
  required Document document,
  required String title,
  required DocumentController controller,
  required ScaffoldMessengerState messenger,
}) => Navigator.push(
  context,
  MaterialPageRoute<void>(
    builder: (_) => DocumentBackupsScreen(
      document.key,
      title: title,
      onOpen: (context, backup) => _compare(
        context,
        backup,
        controller: controller,
        messenger: messenger,
      ),
    ),
  ),
);

/// Compares [backup] with the document's text; once restored, the list
/// closes too.
Future<void> _compare(
  BuildContext context,
  FolderBackup backup, {
  required DocumentController controller,
  required ScaffoldMessengerState messenger,
}) async {
  final navigator = Navigator.of(context);
  final current = await controller.textNow();
  if (!context.mounted) return;
  final restored = await navigator.push(
    MaterialPageRoute<String>(
      builder: (_) => RestoreIntoDocumentScreen(
        backup,
        current: current,
        canRestore: controller.canEdit(),
      ),
    ),
  );
  if (restored == null) return;
  final failure = switch (await controller.restore(restored)) {
    RestoreOutcome.restored => null,
    RestoreOutcome.notEditable =>
      "The document can't be edited here now, so nothing was restored.",
    RestoreOutcome.notBackedUp =>
      "The document's text could not be backed up, so nothing was restored.",
  };
  if (failure != null) {
    messenger.showHint(failure);
  } else if (navigator.mounted) {
    navigator.pop();
  }
}
