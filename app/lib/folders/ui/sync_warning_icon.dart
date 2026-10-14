import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folder_services.dart';
import '../folder_sync_status.dart';
import '../note_folder.dart';

/// A small warning sign if the sync tool may not sync [folder]; the full
/// warning is on the folders screen. Shows nothing otherwise.
class SyncWarningIcon extends ConsumerWidget {
  const SyncWarningIcon(this.folder, {super.key});

  final NoteFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider(folder.location));
    if (status case AsyncData(value: SyncStatus.notSynced)) {
      final tool = ref
          .watch(folderServicesProvider(folder.location))
          .syncToolName;
      return Tooltip(
        message: 'Not inside a $tool folder',
        child: Icon(
          Icons.warning_amber,
          size: 16,
          color: Theme.of(context).colorScheme.error,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
