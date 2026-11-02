import 'package:truce_core/truce_core.dart';

/// The plugins the app works with, in the order the user is offered
/// them.
final class FolderPlugins {
  const FolderPlugins(this.all);

  final List<FolderPlugin> all;

  /// The plugin with [id], as kept in a folder's id: one of [all], as the
  /// app only keeps ids of its own plugins.
  FolderPlugin of(String id) =>
      byId(id) ?? (throw StateError('No folder plugin $id'));

  /// The plugin with [id]; `null` if the app has none such.
  FolderPlugin? byId(String id) =>
      all.where((plugin) => plugin.id == id).firstOrNull;
}
