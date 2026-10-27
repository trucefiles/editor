import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../documents/document.dart';
import '../all_backups.dart';
import '../backup_retention.dart';
import '../document_backups.dart';
import 'backup_list.dart';

/// The backups of one document, newest first; tapping one calls [onOpen].
class DocumentBackupsScreen extends ConsumerWidget {
  const DocumentBackupsScreen(
    this.document, {
    required this.title,
    required this.onOpen,
    super.key,
  });

  final DocumentKey document;

  /// The document's title.
  final String title;

  final void Function(BuildContext context, FolderBackup backup) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) => BackupList(
    title: 'Backups of $title',
    backups: ref.watch(documentBackupsProvider(document)),
    empty:
        'No backups of this document. It is backed up on this device '
        'before editing and before keeping a version, for '
        '${backupRetention.inDays} days.',
    onOpen: onOpen,
  );
}
