import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../platform/app_storage.dart';
import '../platform/parent_folder_access.dart';
import 'note_folder.dart';

/// The core services for one folder, wired for Syncthing. The only place
/// in the app that picks implementations.
final class FolderServices {
  /// [backupsPath] is the folder's private backup folder in app storage.
  factory FolderServices.syncthing(
    NoteFolder folder, {
    required String backupsPath,
  }) {
    const adapter = SyncthingAdapter();
    const filter = DefaultFileFilter(
      adapter,
      ExtensionFileTypeDetector.standard(),
    );
    final store = LocalFileStore(folder.path, adapter.tempFileName);
    return FolderServices._(
      store: store,
      filter: filter,
      syncToolName: adapter.name,
      syncRoots: const SyncthingRootFinder(
        readLocalFolderNames,
        canReadParents,
      ),
      conflicts: DefaultConflictService(
        folder: store,
        source: SyncthingConflictSource(store, filter),
        backups: ConflictBackups(
          LocalFileStore(backupsPath, adapter.tempFileName),
        ),
      ),
    );
  }

  const FolderServices._({
    required this.store,
    required this.filter,
    required this.syncToolName,
    required this.syncRoots,
    required this.conflicts,
  });

  final FileStore store;
  final FileFilter filter;

  /// The sync tool's name, for the UI.
  final String syncToolName;

  final SyncRootFinder syncRoots;
  final ConflictService conflicts;
}

final folderServicesProvider = Provider.family<FolderServices, NoteFolder>(
  (ref, folder) => FolderServices.syncthing(
    folder,
    backupsPath: ref.watch(appStorageProvider).backupsPath(folder.id),
  ),
);
