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
      scanner: SyncthingFolderScanner(store, filter),
      syncToolName: adapter.name,
      syncCheck: SyncthingSyncCheck(
        folder.path,
        readNames: readLocalFolderNames,
        parentsVisible: canReadParents(folder.path),
      ),
      conflicts: DefaultConflictService(
        folder: store,
        source: SyncthingConflictSource(store),
        backups: conflictBackupsAt(backupsPath),
      ),
    );
  }

  const FolderServices._({
    required this.store,
    required this.scanner,
    required this.syncToolName,
    required this.syncCheck,
    required this.conflicts,
  });

  final FileStore store;
  final FolderScanner scanner;

  /// The sync tool's name, for the UI.
  final String syncToolName;

  final SyncCheck syncCheck;
  final ConflictService conflicts;
}

/// The conflict backups in the app storage folder at [path].
ConflictBackups conflictBackupsAt(String path) => ConflictBackups(
  LocalFileStore(path, const SyncthingAdapter().tempFileName),
);

final folderServicesProvider = Provider.family<FolderServices, NoteFolder>(
  (ref, folder) => FolderServices.syncthing(
    folder,
    backupsPath: ref.watch(appStorageProvider).backupsPath(folder.id),
  ),
);
