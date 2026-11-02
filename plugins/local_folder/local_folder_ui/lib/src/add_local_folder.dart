import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_local_folder/truce_local_folder.dart';

/// The Local folder add page: the user picks a directory with [pick]
/// (`null` if cancelled), nothing more. The new folder's candidate for
/// [plugin]; `null` if the user cancelled, or the pick can't be added (the
/// page tells why). Saves nothing.
Future<List<PluginFolderCandidate>?> addLocalFolder(
  BuildContext context, {
  required LocalFolderPlugin plugin,
  required Future<Uri?> Function() pick,
}) async {
  final picked = await pick();
  if (picked == null) return null;
  final candidate = await plugin.candidateFor(picked);
  if (!context.mounted) return null;
  switch (candidate) {
    case Ok(:final value):
      return [value];
    case Err(:final error):
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(_refusedText(error))));
      return null;
  }
}

String _refusedText(LocalPickRefused refused) => switch (refused) {
  LocalPickRefused.hidden =>
    "A folder inside a hidden folder, e.g. a sync app's own, can't be "
        'added.',
  LocalPickRefused.overlaps =>
    'This folder lies at, inside or around a folder added before.',
};
