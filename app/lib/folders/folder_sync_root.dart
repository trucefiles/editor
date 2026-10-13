import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../platform/parent_folder_access.dart';
import 'folder_services.dart';
import 'note_folder.dart';

/// Where the sync tool syncs [NoteFolder] from; looked up once per app run.
final syncRootProvider = FutureProvider.family<SyncRootSearch, NoteFolder>(
  (ref, folder) => ref
      .watch(folderServicesProvider(folder))
      .syncRoots
      .find(folder.path, parentsVisible: canReadParents(folder.path)),
);
