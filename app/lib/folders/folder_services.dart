import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../platform/app_storage.dart';
import '../platform/device_id.dart';
import 'note_folder.dart';
import 'syncthing_folder_services.dart';

/// The core services for one folder. Built by the sync tool's wiring
/// ([syncthingFolderServices]); the rest of the app sees only this.
final class FolderServices {
  const FolderServices({
    required this.store,
    required this.scanner,
    required this.syncToolName,
    required this.syncCheck,
    required this.conflicts,
    required this.marks,
  });

  final FileStore store;
  final FolderScanner scanner;

  /// The sync tool's name, for the UI.
  final String syncToolName;

  final SyncCheck syncCheck;
  final ConflictService conflicts;
  final NoteMarks marks;
}

/// The only place in the app that picks the sync tool: Syncthing.
final folderServicesProvider = Provider.family<FolderServices, FolderLocation>(
  (ref, location) => syncthingFolderServices(
    location.path,
    backupsPath: ref.watch(appStorageProvider).backupsPath(location.id),
    deviceId: ref.watch(deviceIdProvider),
  ),
);
