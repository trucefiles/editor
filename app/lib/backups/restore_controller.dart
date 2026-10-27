import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../scan/folder_scans.dart';
import '../scan/folder_scans_controller.dart';
import '../sync_tool/folder_services.dart';
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
    final scans = ref.read(folderScansProvider.notifier);
    return RestoreCompare(
      ref.read(folderServicesProvider(start.folder.location)).restore,
      () {
        // The list behind this screen shows the backup of the file replaced.
        if (ref.mounted) ref.invalidate(allBackupsProvider);
        return scans.refresh();
      },
    );
  }

  /// The same backup, as it is now.
  @override
  FolderBackup nextIn(FolderScans scans) => start;
}
