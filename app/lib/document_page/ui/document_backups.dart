import 'package:flutter/material.dart';

import '../../backups/all_backups.dart';
import '../../backups/ui/document_backups_screen.dart';
import '../../backups/ui/restore_into_document_screen.dart';
import '../../common/snack.dart';
import '../../documents/document.dart';
import '../document_controller.dart';

/// Opens the backups of the open [document], whose title is [title];
/// restoring one goes through [controller], into the document (only if
/// [canRestore]), and comes back to it; the editor offers its undo.
/// [messenger] is the document screen's, to tell a failure there.
Future<void> openDocumentBackups(
  BuildContext context, {
  required Document document,
  required String title,
  required DocumentController controller,
  required bool canRestore,
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
        canRestore: canRestore,
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
  required bool canRestore,
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
        canRestore: canRestore,
      ),
    ),
  );
  if (restored == null) return;
  if (!await controller.restore(restored)) {
    messenger.showHint(
      "The document's text could not be backed up, so nothing was restored.",
    );
    return;
  }
  if (navigator.mounted) navigator.pop();
}
