import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import 'folder_services.dart';
import 'note_folder.dart';

/// Whether the sync tool syncs [NoteFolder]; checked once per app run.
final syncStatusProvider = FutureProvider.family<SyncStatus, NoteFolder>(
  (ref, folder) => ref.watch(folderServicesProvider(folder)).syncCheck.check(),
);
