import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/error_text.dart';
import '../../common/snack.dart';
import '../../platform/folder_picker.dart';
import '../folder_selection.dart';
import '../folders_controller.dart';
import '../note_folder.dart';
import 'folder_badge.dart';
import 'folder_edit_dialog.dart';

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
              subtitle: Text(folder.path),
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
    final saved = await ref.read(foldersProvider.notifier).change(changed);
    if (saved case Err(:final error) when context.mounted) {
      showSnack(context, error.text);
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    NoteFolder folder,
  ) async {
    final confirmed = await showDialog<bool>(
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
    );
    if (confirmed != true) return;
    if (ref.read(selectedFolderIdProvider) == folder.id) {
      ref.read(selectedFolderIdProvider.notifier).choose(null);
    }
    final saved = await ref.read(foldersProvider.notifier).remove(folder);
    if (saved case Err(:final error) when context.mounted) {
      showSnack(context, error.text);
    }
  }
}

/// Lets the user pick a folder and adds it.
Future<void> addFolder(BuildContext context, WidgetRef ref) async {
  final path = await ref.read(folderPickerProvider).pick();
  if (path == null) return;
  final added = await ref.read(foldersProvider.notifier).add(path);
  if (added case Err(:final error) when context.mounted) {
    showSnack(context, error.text);
  }
}
