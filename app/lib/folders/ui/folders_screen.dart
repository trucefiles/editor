import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_common_ui/truce_common_ui.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../common/snack.dart';
import '../add_folder/ui/add_folder_screen.dart';
import '../folder_actions.dart';
import '../folders_controller.dart';
import '../open_folders_wiring.dart';
import 'folder_badge.dart';
import 'folder_error_text.dart';
import 'folder_notices_view.dart';
import 'folder_settings_screen.dart';
import 'reorderable_folder_list.dart';

/// Opens the [FoldersScreen]. Notices can change while the app runs (e.g.
/// watching a folder failed), so they are checked again first.
Future<void> openFoldersScreen(BuildContext context, WidgetRef ref) {
  ref.invalidate(folderNoticesProvider);
  return Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => const FoldersScreen()),
  );
}

/// Lists the folders on this device in their order: add, change,
/// reorder by dragging, remove.
class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Manage folders')),
      // Nothing can be added to a list that can't be read.
      floatingActionButton: ref.watch(folderListStateProvider) is FoldersLoaded
          ? FloatingActionButton.extended(
              onPressed: () => addFolder(context, ref),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Add folder'),
            )
          : null,
      body: PageWidth(
        builder: (_, padding) => ReorderableFolderList(
          folders,
          padding: padding,
          onMove: (folder, to) => _move(context, ref, folder, to: to),
          tile: (folder, index) => ListTile(
            key: ValueKey(folder.id),
            leading: FolderDot(folder.color, size: 16),
            title: Text(folder.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(folder.location), FolderNoticesView(folder)],
            ),
            onTap: () => _edit(context, ref, folder),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Remove from app',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _remove(context, ref, folder),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Tooltip(
                    message: 'Drag to reorder',
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_handle),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Moves [folder] to place [to]; whether it was saved.
  Future<bool> _move(
    BuildContext context,
    WidgetRef ref,
    Folder folder, {
    required int to,
  }) async {
    final saved = await ref.read(folderActionsProvider).move(folder, to: to);
    if (saved case Err(:final error) when context.mounted) {
      showSnack(context, error.text);
    }
    return saved is Ok;
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Folder folder) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => FolderSettingsScreen(folder)),
      );

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Folder folder,
  ) async {
    final actions = ref.read(folderActionsProvider);
    final lost = await actions.draftsLostByRemoving(folder);
    if (!context.mounted || !await _confirmRemove(context, folder, lost)) {
      return;
    }
    final saved = await actions.remove(folder);
    if (saved case Err(:final error) when context.mounted) {
      showSnack(context, error.text);
    }
  }

  /// Whether the user wants to remove [folder] from the app; the edits
  /// of [lost] files kept only on this device may be lost.
  Future<bool> _confirmRemove(
    BuildContext context,
    Folder folder,
    int lost,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Remove "${folder.name}"?'),
          content: Text(switch (lost) {
            0 =>
              'The folder disappears from the app. Its files stay where '
                  'they are.',
            1 =>
              'The folder disappears from the app. Its files stay where '
                  'they are, but edits to 1 file that are only on this '
                  'device may be lost.',
            _ =>
              'The folder disappears from the app. Its files stay where '
                  'they are, but edits to $lost files that are only on this '
                  'device may be lost.',
          }),
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
          'To open your synced folders, the app needs access to '
          'files. It only opens the folders you add. Turn on the '
          'switch on the next page, then come back to add a folder.',
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
