import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_folders/truce_folders.dart';

import '../platform/platform_wiring.dart';
import 'plain_folder/plain_folder_wiring.dart';
import 'syncthing/syncthing_wiring.dart';

/// The sync tools the app works with: the one place that registers them,
/// at compile time.
final syncToolsProvider = Provider<SyncTools>((ref) {
  final disk = ref.watch(localDiskProvider);
  return SyncTools([syncthingTool(disk), plainFolderTool(disk)]);
});
