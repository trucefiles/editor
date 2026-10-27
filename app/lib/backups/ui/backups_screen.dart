import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../all_backups.dart';
import '../backup_retention.dart';
import 'backup_list.dart';
import 'restore_screen.dart';

/// Every document backup on this device, newest first; tapping one compares it
/// with the document to restore it.
class BackupsScreen extends ConsumerWidget {
  const BackupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => BackupList(
    title: 'Backups',
    backups: ref.watch(allBackupsProvider),
    empty:
        'No backups. Documents are backed up on this device before '
        'editing and before keeping a version, for '
        '${backupRetention.inDays} days.',
    onOpen: openRestore,
  );
}

/// Opens the list of all backups.
Future<void> openBackups(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => const BackupsScreen()),
);
