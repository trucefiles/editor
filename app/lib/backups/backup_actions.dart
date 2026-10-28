import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../sync_tool/base_folder_services.dart';
import 'all_backups.dart';
import 'document_backups.dart';

final backupActionsProvider = Provider<BackupActions>(BackupActions.new);

/// The user's actions on backups that change no document. No UI.
final class BackupActions {
  BackupActions(this._ref);

  final Ref _ref;

  /// Deletes [backup]; the lists show it gone.
  Future<Result<void, StoreError>> delete(FolderBackup backup) async {
    final deleted = await _ref
        .read(baseFolderServicesProvider(backup.folder.base))
        .backups
        .delete(backup.backup);
    _ref
      ..invalidate(allBackupsProvider)
      ..invalidate(documentBackupsProvider);
    return deleted;
  }
}
