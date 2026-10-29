import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../common/snack.dart';
import '../../sync_tool/base_folder_wiring.dart';
import '../add_folder/ui/add_folder_screen.dart';
import '../folder_actions.dart';
import '../folders_controller.dart';
import 'folder_badge.dart';
import 'folder_error_text.dart';
import 'folder_notices_view.dart';
import 'folder_settings_screen.dart';

/// Opens the [FoldersScreen]. Notices can change while the app runs (e.g.
/// watching a folder failed), so they are checked again first.
Future<void> openFoldersScreen(BuildContext context, WidgetRef ref) {
  ref.invalidate(folderNoticesProvider);
  return Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => const FoldersScreen()),
  );
}

/// Lists the folders on this device: add, change, remove.
class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Manage folders')),
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
                children: [Text(_shownOf(folder)), FolderNoticesView(folder)],
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

  /// Where [folder] is, and what it shows there.
  static String _shownOf(DocumentFolder folder) => switch (folder.selection) {
    WholeFolder() => folder.base.shownAddress,
    Subfolders(:final roots) => [
      for (final root in roots) '${folder.base.shownAddress}/${root.value}',
    ].join('\n'),
  };

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    DocumentFolder folder,
  ) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => FolderSettingsScreen(folder)),
  );

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    DocumentFolder folder,
  ) async {
    if (!await _confirmRemove(context, folder)) return;
    final saved = await ref.read(folderActionsProvider).remove(folder);
    if (saved case Err(:final error) when context.mounted) {
      showSnack(context, error.text);
    }
  }

  /// Whether the user wants to remove [folder] from the app.
  Future<bool> _confirmRemove(
    BuildContext context,
    DocumentFolder folder,
  ) async =>
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

/// Makes sure the app may open folders, then adds one step by step.
Future<void> addFolder(BuildContext context, WidgetRef ref) async {
  final actions = ref.read(folderActionsProvider);
  if (!await actions.hasAccess()) {
    if (context.mounted && await _askForAccess(context)) {
      await actions.requestAccess();
    }
    return;
  }
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => const AddFolderScreen()),
  );
}

/// Explains why the app needs all-files access; `true` to continue.
Future<bool> _askForAccess(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow file access'),
        content: const Text(
          'To edit documents in your synced folders, Android needs to allow '
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
