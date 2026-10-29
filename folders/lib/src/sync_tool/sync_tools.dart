import 'package:truce_core/truce_core.dart';

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

  /// Whether the folder at [address] belongs to any of the tools itself
  /// (e.g. its version folder).
  bool isToolFolder(Uri address) =>
      all.any((tool) => tool.isToolFolder(address));
}
