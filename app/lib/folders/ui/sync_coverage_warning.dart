import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folder_services.dart';
import '../folder_sync_coverage.dart';
import '../note_folder.dart';

/// Warns that the sync tool may not sync [folder]. Shows nothing while
/// checking or when the folder is synced.
class SyncCoverageWarning extends ConsumerWidget {
  const SyncCoverageWarning(
    this.folder, {
    this.includeUnknown = false,
    this.showFolderName = false,
    super.key,
  });

  final NoteFolder folder;

  /// Also says when the check was not possible (e.g. in a sandbox).
  final bool includeUnknown;

  /// Starts the text with the folder's name, for lists of all folders.
  final bool showFolderName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tool = ref.watch(folderServicesProvider(folder)).syncToolName;
    final error = Theme.of(context).colorScheme.error;
    final shown = switch (ref.watch(syncCoverageProvider(folder))) {
      AsyncData(value: SyncCoverage.notSynced) => (
        Icons.warning_amber,
        error,
        'Not inside a $tool folder. Changes may not reach your other '
            'devices.',
      ),
      AsyncData(value: SyncCoverage.unknown) when includeUnknown => (
        Icons.info_outline,
        null,
        "Can't check whether $tool syncs this folder. Add the $tool "
            'folder itself to confirm.',
      ),
      _ => null,
    };
    if (shown == null) return const SizedBox.shrink();
    final (icon, color, message) = shown;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Icon(icon, size: 18, color: color),
          Expanded(
            child: Text(
              showFolderName ? '${folder.name}: $message' : message,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
