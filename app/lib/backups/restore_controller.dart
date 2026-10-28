import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../documents/document.dart';
import '../folder_state/folder_contents.dart';
import '../folder_state/folder_state_controller.dart';
import '../sync_tool/base_folder_services.dart';
import '../versions/compare_controller.dart';
import 'all_backups.dart';
import 'restore_compare.dart';

/// What the restore screen shows.
typedef RestoreState = CompareState<FolderBackup, RestoreChoice>;

final restoreProvider = NotifierProvider.autoDispose
    .family<RestoreController, RestoreState, FolderBackup>(
      RestoreController.new,
    );

/// Shows one backup next to its document's file; the user keeps one of
/// them. A keep that worked ends it; after a failed one, both load again,
/// to show the file as it is now.
class RestoreController extends CompareController<FolderBackup, RestoreChoice> {
  RestoreController(super.start);

  @override
  bool get goesOn => false;

  @override
  CompareSource<FolderBackup, RestoreChoice> source() {
    final folderState = ref.read(folderContentsProvider.notifier);
    return RestoreCompare(
      ref.read(baseFolderServicesProvider(start.folder.base)).restore,
      () {
        // The list behind this screen shows the backup of the file replaced.
        if (ref.mounted) ref.invalidate(allBackupsProvider);
        return folderState.refresh();
      },
    );
  }

  @override
  DocumentKey get document =>
      (baseId: start.folder.base.id, path: start.backup.filePath);

  /// The same backup, as it is now.
  @override
  FolderBackup nextIn(FolderContents contents) => start;
}
