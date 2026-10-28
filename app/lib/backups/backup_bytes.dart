import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../sync_tool/base_folder_services.dart';
import 'all_backups.dart';

/// What [FolderBackup] holds, read each time it is shown.
final backupBytesProvider = FutureProvider.autoDispose
    .family<Result<Uint8List, StoreError>, FolderBackup>(
      (ref, backup) => ref
          .watch(baseFolderServicesProvider(backup.folder.base))
          .backups
          .read(backup.backup),
    );
