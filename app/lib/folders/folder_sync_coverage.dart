import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../platform/parent_folder_access.dart';
import 'folder_services.dart';
import 'note_folder.dart';

/// Whether the sync tool syncs [NoteFolder]; checked once per app run.
final syncCoverageProvider = FutureProvider.family<SyncCoverage, NoteFolder>(
  (ref, folder) => ref
      .watch(folderServicesProvider(folder))
      .syncCoverage
      .check(folder.path, parentsVisible: canReadParents(folder.path)),
);
