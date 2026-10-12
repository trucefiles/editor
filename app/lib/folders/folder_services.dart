import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import 'note_folder.dart';

/// The core services for one folder, wired for Syncthing. The only place
/// in the app that picks implementations.
final class FolderServices {
  factory FolderServices.syncthing(NoteFolder folder) {
    const adapter = SyncthingAdapter();
    return FolderServices._(
      store: LocalFileStore(folder.path, adapter.tempFileName),
      filter: const DefaultFileFilter(
        adapter,
        ExtensionFileTypeDetector.standard(),
      ),
    );
  }

  const FolderServices._({required this.store, required this.filter});

  final FileStore store;
  final FileFilter filter;
}

final folderServicesProvider = Provider.family<FolderServices, NoteFolder>(
  (ref, folder) => FolderServices.syncthing(folder),
);
