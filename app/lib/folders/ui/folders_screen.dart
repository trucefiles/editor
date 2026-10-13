import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/snack.dart';
import '../folder_actions.dart';
import '../folders_controller.dart';
import '../note_folder.dart';
import 'add_folder_error_text.dart';
import 'folder_badge.dart';
import 'folder_edit_dialog.dart';
import 'settings_error_text.dart';
import 'sync_status_warning.dart';

/// Lists the folders on this device: add, rename, recolor, remove.
class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Folders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addFolder(context, ref),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Add folder'),
      ),
      body: ListView(
        children: [
          for (final folder in folders)
            ListTile(
              leading: FolderDot(folder.color, size: 16),
              title: Text(folder.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(folder.path),
                  SyncStatusWarning(folder, includeUnknown: true),
                ],
              ),
              onTap: () => _edit(context, ref, folder),
              trailing: IconButton(
                tooltip: 'Remove from app',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => _remove(context, ref, folder),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    NoteFolder folder,
  ) async {
    final changed = await showFolderEditDialog(context, folder);
    if (changed == null) return;
    final saved = await ref.read(folderActionsProvider).change(changed);
    if (saved case Err(:final error) when context.mounted) {
      showSnack(context, error.text);
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    NoteFolder folder,
  ) async {
    if (!await _confirmRemove(context, folder)) return;
    final saved = await ref.read(folderActionsProvider).remove(folder);
    if (saved case Err(:final error) when context.mounted) {
      showSnack(context, error.text);
    }
  }

  /// Whether the user wants to remove [folder] from the app.
  Future<bool> _confirmRemove(BuildContext context, NoteFolder folder) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Remove "${folder.name}"?'),
          content: const Text(
            'The app stops showing this folder. Its files stay untouched.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      ) ??
      false;
}

/// Makes sure the app may open folders, lets the user pick one and adds
/// it.
Future<void> addFolder(BuildContext context, WidgetRef ref) async {
  final actions = ref.read(folderActionsProvider);
  if (!await actions.hasAccess()) {
    if (context.mounted && await _askForAccess(context)) {
      await actions.requestAccess();
    }
    return;
  }
  final added = await actions.pickAndAdd();
  if (added case Err(:final error) when context.mounted) {
    showSnack(context, error.text);
  }
}

/// Explains why the app needs all-files access; `true` to continue.
Future<bool> _askForAccess(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow file access'),
        content: const Text(
          'To edit notes in your synced folders, Android needs to allow '
          'this app access to files. The app only opens the folders you '
          'add here. Turn on the switch on the next page, then come back '
          'and add a folder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    ) ??
    false;
