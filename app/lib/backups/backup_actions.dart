import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/base_folder.dart';
import '../sync_tool/base_folder_services.dart';
import '../sync_tool/base_folder_wiring.dart';
import 'all_backups.dart';
import 'document_backups.dart';
import 'folder_backups.dart';

final backupActionsProvider = Provider<BackupActions>(
  (ref) => BackupActions(
    servicesOf: ref.watch(baseFolderStacksProvider).servicesOf,
    changed: () => ref
      ..invalidate(allBackupsProvider)
      ..invalidate(documentBackupsProvider),
  ),
);

/// The user's actions on backups that change no document. No UI.
final class BackupActions {
  /// [_servicesOf] gives a base folder's services; [_changed] tells the
  /// lists of backups to read them again.
  BackupActions({required this._servicesOf, required this._changed});

  final BaseFolderServices Function(BaseFolder base) _servicesOf;
  final void Function() _changed;

  /// Deletes [backup]; the lists show it gone.
  Future<Result<void, StoreError>> delete(FolderBackup backup) async {
    final deleted = await _servicesOf(backup.folder.base).backups
        .delete(backup.backup);
    _changed();
    return deleted;
  }
}
