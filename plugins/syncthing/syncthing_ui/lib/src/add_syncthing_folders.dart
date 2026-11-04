import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_syncthing/truce_syncthing.dart';

import 'root_not_found_dialog.dart';
import 'syncthing_tree_page.dart';

/// Syncthing's add page: the user picks a directory with [pick] (`null`
/// if cancelled), the page finds its Syncthing folder and shows that
/// folder's tree to tick the folders to add. The new folders' candidates
/// for [plugin]; `null` if the user cancelled anywhere, or the pick can't
/// be added (the page tells why). Saves nothing.
Future<List<PluginFolderCandidate>?> addSyncthingFolders(
  BuildContext context, {
  required SyncthingPlugin plugin,
  required Future<Uri?> Function() pick,
}) async {
  final picked = await pick();
  if (picked == null || !context.mounted) return null;
  final search = await plugin.findRoot(picked);
  if (!context.mounted) return null;
  return switch (search) {
    final RootFound found => _pickIn(context, plugin, found),
    final RootNotFound notFound => _notFound(context, plugin, notFound, pick),
  };
}

/// No Syncthing folder holds the pick: the user picks the Syncthing
/// folder itself, or goes on with the pick as one.
Future<List<PluginFolderCandidate>?> _notFound(
  BuildContext context,
  SyncthingPlugin plugin,
  RootNotFound notFound,
  Future<Uri?> Function() pick,
) async {
  final choice = await showRootNotFound(context);
  if (!context.mounted) return null;
  return switch (choice) {
    // No version history, no ignore rules: the pick is the root.
    RootChoice.continueHere => _pickIn(
      context,
      plugin,
      RootFound(
        root: notFound.picked,
        rootHost: notFound.pickedHost,
        pick: null,
      ),
    ),
    RootChoice.pickRoot => addSyncthingFolders(
      context,
      plugin: plugin,
      pick: pick,
    ),
    null => null,
  };
}

/// The folders the user ticks in the Syncthing folder [found], as
/// candidates; `null` if none, or if that Syncthing folder can't be added.
Future<List<PluginFolderCandidate>?> _pickIn(
  BuildContext context,
  SyncthingPlugin plugin,
  RootFound found,
) async {
  if (plugin.rootClash(found.rootHost) case final clash?) {
    _tell(
      context,
      'This Syncthing folder overlaps ${shownAddress(clash)}, '
      'which is already in the app. Remove that one first to add '
      'this one.',
    );
    return null;
  }
  if (plugin.rootInHidden(found.root, found.rootHost) ||
      !plugin.shows(found.pick)) {
    _tell(
      context,
      "Hidden folders and Syncthing's own folders can't be added.",
    );
    return null;
  }
  final ticked = await Navigator.push<List<RelPath?>>(
    context,
    MaterialPageRoute(
      builder: (_) => SyncthingTreePage(
        names: plugin.subfoldersOf(found.root),
        rootName: lastSegment(found.root),
        taken: plugin.takenIn(found.rootHost),
        initial: found.pick,
      ),
    ),
  );
  return switch (ticked) {
    final ticked? => [
      for (final path in ticked)
        plugin.candidate(found.root, found.rootHost, path),
    ],
    null => null,
  };
}

void _tell(BuildContext context, String text) =>
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text)));
