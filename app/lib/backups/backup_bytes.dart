import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../sync_tool/folder_services.dart';
import 'all_backups.dart';

/// What [FolderBackup] holds, read each time it is shown.
final backupBytesProvider = FutureProvider.autoDispose
    .family<Result<Uint8List, StoreError>, FolderBackup>(
      (ref, backup) => ref
          .watch(folderServicesProvider(backup.folder.location))
          .backups
          .read(backup.backup),
    );
