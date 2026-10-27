import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/error_text.dart';
import '../../common/snack.dart';
import '../../versions/ui/compare_app_bar.dart';
import '../../versions/ui/version_chooser.dart';
import '../../versions/version_text.dart';
import '../all_backups.dart';
import '../backup_bytes.dart';
import '../backup_retention.dart';
import 'backup_kind_text.dart';

/// Shows a backup next to the open document's text [current], in the same
/// view as a conflict. Closes with the backup's text once the user
/// restores it, with `null` if they keep the text; nothing is changed
/// here. Restoring is off unless [canRestore].
class RestoreIntoDocumentScreen extends ConsumerWidget {
  const RestoreIntoDocumentScreen(
    this.backup, {
    required this.current,
    required this.canRestore,
    super.key,
  });

  final FolderBackup backup;
  final String current;
  final bool canRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:folder, backup: shown) = backup;
    return Scaffold(
      appBar: compareAppBar(
        folder: folder,
        file: shown.filePath,
        reason: 'Backup: ${shown.kind.text}',
      ),
      body: switch (ref.watch(backupBytesProvider(backup))) {
        AsyncData(value: Ok(value: final bytes)) => VersionChooser(
          current: ShownVersion(
            label: 'This document now',
            text: current,
            keepLabel: 'Keep this',
            keptMessage: 'The document stays as it is.',
          ),
          other: ShownVersion(
            label: 'Backup',
            modified: shown.savedAt,
            text: versionText(bytes),
            keepLabel: 'Restore',
            keptMessage:
                'The document shows the backup instead; Undo takes it '
                'back. A backup of the text now stays on this device for '
                '${backupRetention.inDays} days.',
          ),
          enabled: canRestore,
          onKeep: (side) => _keep(context, side, bytes),
        ),
        AsyncData(value: Err(:final error)) => Center(child: Text(error.text)),
        AsyncError() => const Center(
          child: Text('The backup could not be read.'),
        ),
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  void _keep(BuildContext context, VersionSide side, Uint8List bytes) {
    if (side == VersionSide.current) return Navigator.pop(context);
    switch (TextFile.decode(bytes)) {
      case final file?:
        Navigator.pop(context, file.text);
      case null:
        showSnack(context, 'This backup is not text this app can show.');
    }
  }
}
