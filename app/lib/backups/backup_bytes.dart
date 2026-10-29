import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';

import '../sync_tool/base_folder_wiring.dart';

/// What [FolderBackup] holds, read each time it is shown.
final backupBytesProvider = FutureProvider.autoDispose
    .family<Result<Uint8List, StoreError>, FolderBackup>(
      (ref, backup) => ref
          .watch(baseFolderServicesProvider(backup.folder.base))
          .backups
          .read(backup.backup),
    );
