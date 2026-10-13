import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import 'folder_services.dart';
import 'note_folder.dart';

/// Whether the sync tool syncs the folder at [FolderLocation]; checked once
/// per app run.
final syncStatusProvider = FutureProvider.family<SyncStatus, FolderLocation>(
  (ref, location) =>
      ref.watch(folderServicesProvider(location)).syncCheck.check(),
);
