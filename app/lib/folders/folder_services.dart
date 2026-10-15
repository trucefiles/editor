import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../platform/app_storage.dart';
import '../platform/device_id.dart';
import '../refresh/refresh_settings_controller.dart';
import 'note_folder.dart';
import 'syncthing_folder_services.dart';

/// The core services for one folder. Built by the sync tool's wiring
/// ([syncthingFolderServices]); the rest of the app sees only this.
final class FolderServices {
  const FolderServices({
    required this.store,
    required this.scanner,
    required this.syncToolName,
    required this.conflicts,
    required this.backups,
    required this.restore,
    required this.marks,
  });

  final FileStore store;
  final FolderScanner scanner;

  /// The sync tool's name, for the UI.
  final String syncToolName;

  final ConflictService conflicts;

  /// Copies of the folder's files in app storage.
  final FileBackups backups;

  /// Puts [backups] back into the folder.
  final BackupRestore restore;

  final NoteMarks marks;
}

/// Picks the sync tool, Syncthing, for a folder's services. This file is
/// the only place that picks it.
final folderServicesProvider = Provider.family<FolderServices, FolderLocation>(
  (ref, location) => syncthingFolderServices(
    location.path,
    backupsPath: ref.watch(appStorageProvider).backupsPath(location.id),
    deviceId: ref.watch(deviceIdProvider),
  ),
);

/// The sync tool's file-name rules, e.g. to refuse adding a folder of its
/// own. Picks the same sync tool as [folderServicesProvider].
final syncAdapterProvider = Provider<SyncAdapter>((_) => syncthingAdapter);

/// How a folder's changes are found (`null`: not looked for), and what the
/// user should know about the folder. Built together by the sync tool's
/// wiring, so the notices can tell how changes are actually followed.
typedef FolderFollowing = ({FolderChanges? changes, FolderNotices notices});

final _folderFollowingProvider =
    FutureProvider.family<FolderFollowing, FolderLocation>(
      (ref, location) async => syncthingFolderFollowing(
        location.path,
        await ref.watch(refreshSettingsProvider.future),
      ),
    );

/// How changes to the folder at [FolderLocation] are found, as the refresh
/// setting asks; `null` if they aren't looked for (manual refresh).
final folderChangesProvider =
    FutureProvider.family<FolderChanges?, FolderLocation>(
      (ref, location) async =>
          (await ref.watch(_folderFollowingProvider(location).future)).changes,
    );

/// What the user should know about the folder at [FolderLocation]. Checked
/// once; invalidate to check again.
final folderNoticesProvider =
    FutureProvider.family<List<FolderNotice>, FolderLocation>(
      (ref, location) async =>
          (await ref.watch(_folderFollowingProvider(location).future)).notices
              .check(),
    );
