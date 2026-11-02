import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../folders/open_folders_wiring.dart';
import 'all_backups.dart';
import 'file_backups.dart';

final backupActionsProvider = Provider<BackupActions>(
  (ref) => BackupActions(
    servicesOf: ref.watch(openFoldersProvider).servicesOf,
    changed: () => ref
      ..invalidate(allBackupsProvider)
      ..invalidate(fileBackupsProvider),
  ),
);

/// The user's actions on backups that change no file. No UI.
final class BackupActions {
  /// [_servicesOf] gives a folder's services; [_changed] tells the
  /// lists of backups to read them again.
  BackupActions({required this._servicesOf, required this._changed});

  final FolderServices Function(FolderId folder) _servicesOf;
  final void Function() _changed;

  /// Deletes [backup]; the lists show it gone.
  Future<Result<void, StoreError>> delete(FolderBackup backup) async {
    final deleted = await _servicesOf(backup.folder.id).backups
        .delete(backup.backup);
    _changed();
    return deleted;
  }
}
