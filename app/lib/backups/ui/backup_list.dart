import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_common_ui/truce_common_ui.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../../common/empty_state.dart';
import '../../common/snack.dart';
import '../../common/store_error_text.dart';
import '../../common/time_texts.dart';
import '../../files/ui/listed_file.dart';
import '../../folders/ui/folder_badge.dart';
import '../backup_actions.dart';
import 'backup_kind_text.dart';

/// A screen listing [backups] under [title], newest first, rows built as
/// they scroll in; tapping one calls [onOpen], and each can be deleted.
/// [empty] tells what shows when there is none.
class BackupList extends StatelessWidget {
  const BackupList({
    required this.title,
    required this.backups,
    required this.empty,
    required this.onOpen,
    super.key,
  });

  final String title;
  final AsyncValue<List<FolderBackup>> backups;
  final String empty;
  final void Function(BuildContext context, FolderBackup backup) onOpen;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: switch (backups) {
      AsyncData(value: final backups) when backups.isEmpty => EmptyState(
        icon: Icons.history,
        text: empty,
      ),
      AsyncData(value: final backups) => PageWidth(
        builder: (_, padding) => ListView.builder(
          padding: padding,
          itemCount: backups.length,
          itemBuilder: (context, index) => _BackupTile(
            backups[index],
            onOpen: () => onOpen(context, backups[index]),
          ),
        ),
      ),
      AsyncError() => const Center(
        child: Text('The backups could not be read.'),
      ),
      AsyncLoading() => const Center(child: CircularProgressIndicator()),
    },
  );
}

class _BackupTile extends ConsumerWidget {
  const _BackupTile(this.backup, {required this.onOpen});

  final FolderBackup backup;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:folder, backup: shown) = backup;
    final title = watchTitle(ref, (folder: folder.id, path: shown.filePath));
    return ListTile(
      leading: const Icon(Icons.history),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${shown.kind.text}, ${ref.watch(timeTextsProvider).full(shown.savedAt)}',
          ),
          FolderBadge(folder, file: shown.filePath),
        ],
      ),
      trailing: PopupMenuButton<VoidCallback>(
        tooltip: 'Backup options',
        onSelected: (action) => action(),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: () => _delete(context, ref),
            child: const Text('Delete backup'),
          ),
        ],
      ),
      onTap: onOpen,
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!await _confirmDelete(context)) return;
    final deleted = await ref.read(backupActionsProvider).delete(backup);
    if (deleted case Err(:final error) when context.mounted) {
      showSnack(context, error.text);
    }
  }

  static Future<bool> _confirmDelete(BuildContext context) => showConfirmDialog(
    context,
    title: 'Delete this backup?',
    message: "This can't be undone. The file itself stays.",
    yes: 'Delete',
  );
}
