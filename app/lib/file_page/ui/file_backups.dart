import 'package:flutter/material.dart';
import 'package:truce_files/truce_files.dart';

import '../../backups/ui/file_backups_screen.dart';
import '../../backups/ui/restore_into_file_screen.dart';
import '../../common/snack.dart';
import '../file_controller.dart';

/// Opens the backups of the open [file], whose title is [title];
/// restoring one goes through [controller], into the file (while it
/// can be edited), and comes back to it; the editor offers its undo.
/// [messenger] is the file screen's, to tell a failure there.
Future<void> openFileBackups(
  BuildContext context, {
  required ListedFile file,
  required String title,
  required FileController controller,
  required ScaffoldMessengerState messenger,
}) => Navigator.push(
  context,
  MaterialPageRoute<void>(
    builder: (_) => FileBackupsScreen(
      file.key,
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

/// Compares [backup] with the file's text; once restored, the list
/// closes too.
Future<void> _compare(
  BuildContext context,
  FolderBackup backup, {
  required FileController controller,
  required ScaffoldMessengerState messenger,
}) async {
  final navigator = Navigator.of(context);
  final current = await controller.textNow();
  if (!context.mounted) return;
  final restored = await navigator.push(
    MaterialPageRoute<String>(
      builder: (_) => RestoreIntoFileScreen(
        backup,
        current: current,
        canRestore: !controller.readOnly,
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
