import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../backups/file_backups_at.dart';
import '../file_types/document_types.dart';
import '../folders/base_folder.dart';
import '../folders/folder_lookup.dart';
import '../folders/folders_controller.dart';
import '../refresh/refresh_settings.dart';
import '../refresh/refresh_settings_controller.dart';
import '../storage/app_storage.dart';
import '../storage/device_id.dart';
import 'app_writes.dart';
import 'sync_tools.dart';

/// The core services for one base folder, by its sync tool, bounded to
/// what its folders show; the rest of the app sees only this.
final class BaseFolderServices {
  const BaseFolderServices({
    required this.store,
    required this.scanner,
    required this.syncToolName,
    required this.conflicts,
    required this.backups,
    required this.restore,
    required this.marks,
    required this.reach,
    required this.notices,
    required this.changes,
    required this.shown,
  });

  /// The base folder's files, by its sync tool; refuses anything outside
  /// what its folders show ([StoreError.outside]); tells [reach] how each
  /// access went.
  final FileStore store;
  final FolderScanner scanner;

  /// The sync tool's name, for the UI.
  final String syncToolName;

  final ConflictService conflicts;

  /// Copies of the base folder's files in app storage.
  final FileBackups backups;

  /// Puts [backups] back into the base folder.
  final BackupRestore restore;

  final DocumentMarks marks;

  /// Whether the base folder can be reached, as accesses through [store]
  /// show.
  final FolderReach reach;

  /// What the sync tool tells about the base folder.
  final FolderNotices notices;

  /// The changes of the documents, the sync tool's records of them and the
  /// marks of all devices, as they happen; `null` where they can't be
  /// followed live.
  final FolderChanges? changes;

  /// Which files and folders the sync tool shows.
  final FileFilter shown;
}

/// A base folder's place by its sync tool, and its reach. They stay while
/// what its folders show changes; only the bounded services above them are
/// built again, so a write still under way in the old services (e.g. a
/// Syncthing rewrite) keeps its files.
final _baseFolderPlaceProvider =
    Provider.family<({ToolPlace place, FolderReach reach}), BaseFolder>((
      ref,
      base,
    ) {
      final place = ref
          .watch(syncToolsProvider)
          .of(base.toolId)
          .place(base.address);
      final reach = folderReach(place.files);
      ref.onDispose(() => unawaited(reach.close()));
      return (place: place, reach: reach);
    });

/// The services of a base folder, built from what its folders show now:
/// built again when that changes. Every write through them is told to
/// [appWritesProvider]. Its open documents are secured before
/// (see `FolderListWork.secureOpen`); a Syncthing rewrite still pending in
/// the stack before ends there, as the user's own write.
final baseFolderServicesProvider =
    Provider.family<BaseFolderServices, BaseFolder>((ref, base) {
      final selection = ref.watch(
        loadedFoldersProvider.select(
          (folders) => (folders.value ?? const []).selectionOf(base),
        ),
      );
      final (:place, :reach) = ref.watch(_baseFolderPlaceProvider(base));
      return baseFolderServices(
        place,
        syncToolName: ref.watch(syncToolsProvider).of(base.toolId).name,
        reach: reach,
        selection: selection,
        types: ref.watch(documentTypesProvider),
        backupsPath: ref.watch(appStorageProvider).backupsPath(base.id),
        deviceId: ref.watch(deviceIdProvider),
        // Read at each wait; an old build's changes may still be followed
        // for a moment after it is replaced.
        checkEvery: () =>
            ((ref.mounted ? ref.read(refreshSettingsProvider).value : null) ??
                    RefreshSettings.standard)
                .interval,
        wrote: (paths) => ref.read(appWritesProvider).wrote(base.id, paths),
      );
    });

/// The folder names of [BaseFolder], for the user to pick subfolders.
final subfolderNamesProvider = Provider.family<SubfolderNames, BaseFolder>(
  (ref, base) => ref.watch(_baseFolderPlaceProvider(base)).place.subfolders,
);

/// The services of a base folder on [place], its sync tool's access to it,
/// whose files tell [reach] how each access went, bounded to [selection]:
/// the files of the handled [types] and the marks. Each write, the sync
/// tool's own included, is told to [wrote]. A followed subfolder that is
/// gone is checked every [checkEvery] whether it is back.
BaseFolderServices baseFolderServices(
  ToolPlace place, {
  required String syncToolName,
  required FolderReach reach,
  required Selection selection,
  required DocumentTypes types,
  required String backupsPath,
  required String deviceId,
  required Duration Function() checkEvery,
  required void Function(Set<RelPath> paths) wrote,
}) {
  // Below the boundary: a write it refuses is never told.
  final bounded = BoundedPlace(
    WriteReportingStore(ReachReportingStore(place.files, reach), wrote),
    place.changes,
    selection,
    handles: (file) =>
        types.handles(file) || DocumentMarks.files.includesFile(file),
    checkEvery: checkEvery,
  );
  final synced = place.open(bounded);
  final backups = fileBackupsAt(backupsPath);
  return BaseFolderServices(
    store: synced.store,
    scanner: synced.scanner,
    syncToolName: syncToolName,
    conflicts: DefaultConflictService(
      folder: synced.store,
      source: synced.conflicts,
      backups: backups,
    ),
    backups: backups,
    restore: BackupRestore(folder: synced.store, backups: backups),
    marks: DocumentMarks(synced.store, deviceId: deviceId),
    reach: reach,
    notices: synced.notices,
    changes: synced.changes,
    shown: synced.shown,
  );
}
