import 'package:flutter/widgets.dart';
import 'package:truce_core/truce_core.dart';

/// A plugin's add page, as the app shows it: asks the user for new
/// folders of that plugin and gives their candidates; `null` if the user
/// cancelled. Saves nothing.
typedef AddPage = Future<List<PluginFolderCandidate>?> Function(
  BuildContext context,
);

/// One plugin as the app wires it: the plugin and its add page.
final class WiredPlugin {
  const WiredPlugin(this.plugin, this.addPage);

  final FolderPlugin plugin;
  final AddPage addPage;
}
