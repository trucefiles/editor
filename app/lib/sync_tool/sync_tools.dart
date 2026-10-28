import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../platform/platform_wiring.dart';
import 'plain_folder/plain_folder_wiring.dart';
import 'syncthing/syncthing_wiring.dart';

/// The sync tools the app works with: the one place that registers them,
/// at compile time.
final syncToolsProvider = Provider<SyncTools>((ref) {
  final disk = ref.watch(localDiskProvider);
  return SyncTools([syncthingTool(disk), plainFolderTool(disk)]);
});

/// The sync tools the app works with, in the order the user is offered
/// them.
final class SyncTools {
  const SyncTools(this.all);

  final List<SyncTool> all;

  /// The tool with [id], as kept with a base folder: one of [all], as the
  /// app only keeps ids of its own tools.
  SyncTool of(String id) => all.firstWhere(
    (tool) => tool.id == id,
    orElse: () => throw StateError('No sync tool $id'),
  );

  /// Whether the folder whose path has the segments [segments] belongs to
  /// any of the tools itself (e.g. its version folder).
  bool isToolFolder(List<String> segments) =>
      all.any((tool) => tool.isToolFolder(segments));
}
