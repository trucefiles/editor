import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/empty_state.dart';
import '../../common/full_time.dart';
import '../../folders/ui/folder_badge.dart';
import '../../scan/folder_scans_controller.dart';
import '../all_backups.dart';
import '../backup_retention.dart';
import 'backup_kind_text.dart';
import 'restore_screen.dart';

/// Every note backup on this device, newest first; tapping one compares it
/// with the note to restore it.
class BackupsScreen extends ConsumerWidget {
  const BackupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backups = ref.watch(allBackupsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Backups')),
      body: switch (backups) {
        AsyncData(value: final backups) when backups.isEmpty => EmptyState(
          icon: Icons.history,
          text:
              'No backups. Notes are backed up on this device before '
              'editing and before keeping a version, for '
              '${backupRetention.inDays} days.',
        ),
        AsyncData(value: final backups) => ListView(
          children: [for (final backup in backups) _BackupTile(backup)],
        ),
        AsyncError() => const Center(
          child: Text('The backups could not be read.'),
        ),
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _BackupTile extends ConsumerWidget {
  const _BackupTile(this.backup);

  final FolderBackup backup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:folder, backup: shown) = backup;
    final note = ref.watch(folderScansProvider).value?.findNote((
      folderId: folder.id,
      path: shown.filePath,
    ));
    final local = MaterialLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.history),
      title: Text(note?.title ?? shown.filePath.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${shown.kind.text}, ${fullTime(local, shown.savedAt)}'),
          FolderBadge(folder, file: shown.filePath),
        ],
      ),
      onTap: () => openRestore(context, backup),
    );
  }
}

/// Opens the list of all backups.
Future<void> openBackups(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => const BackupsScreen()),
);
