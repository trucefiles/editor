import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';

import '../file_backups.dart';
import 'backup_list.dart';

/// The backups of one file, newest first; tapping one calls [onOpen].
class FileBackupsScreen extends ConsumerWidget {
  const FileBackupsScreen(
    this.file, {
    required this.title,
    required this.onOpen,
    super.key,
  });

  final FileKey file;

  /// The file's title.
  final String title;

  final void Function(BuildContext context, FolderBackup backup) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) => BackupList(
    title: 'Backups of $title',
    backups: ref.watch(fileBackupsProvider(file)),
    empty:
        'No backups of this document. It is backed up on this device '
        'before editing and before keeping a version, for '
        '${backupRetention.inDays} days.',
    onOpen: onOpen,
  );
}
