import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../folders/open_folders_wiring.dart';

/// What [FolderBackup] holds, read each time it is shown.
final backupBytesProvider = FutureProvider.autoDispose
    .family<Result<Uint8List, StoreError>, FolderBackup>(
      (ref, backup) => ref
          .watch(folderServicesProvider(backup.folder.id))
          .backups
          .read(backup.backup),
    );
