import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../folder_state/folder_state_controller.dart';
import '../../../folders/folders_controller.dart';
import '../../../folders/ui/folder_badge.dart';
import '../../document_actions.dart';
import '../../document_place.dart';
import '../../ui/document_place_dialog.dart';
import '../new_file_place.dart';
import '../new_file_place_controller.dart';

/// Settings row with where new documents go; opens a dialog to pick a folder
/// and subfolder, and can go back to the default.
class NewFilePlaceTile extends ConsumerWidget {
  const NewFilePlaceTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider).value ?? const [];
    final setting = ref.watch(newFilePlaceProvider);
    ref.watch(folderContentsProvider);
    final actions = ref.read(documentActionsProvider);
    final place = resolveNewFilePlace(setting.value, folders);
    return ListTile(
      enabled: setting.hasValue && folders.isNotEmpty,
      title: const Text('Default folder for new documents'),
      subtitle: place == null
          ? const Text('Folder selected on home, else the first reachable one')
          : Align(
              alignment: AlignmentDirectional.centerStart,
              child: FolderBadge(place.folder, subfolder: place.subfolder),
            ),
      trailing: place == null
          ? null
          : IconButton(
              tooltip: 'Use the default',
              icon: const Icon(Icons.close),
              onPressed: () =>
                  ref.read(newFilePlaceProvider.notifier).set(null),
            ),
      onTap: () async {
        // Change events don't tell about new empty subfolders; a listing
        // finds them, so the dialog offers them.
        await ref.read(folderContentsProvider.notifier).refresh();
        if (!context.mounted) return;
        final picked = await showNotePlaceDialog(
          context,
          title: 'Default folder for new documents',
          action: 'OK',
          folders: folders,
          initial: place ?? topOf(folders.first),
          subfoldersOf: actions.subfoldersOf,
        );
        if (picked == null) return;
        await ref.read(newFilePlaceProvider.notifier).set((
          folderId: picked.folder.id,
          subfolder: picked.subfolder,
        ));
      },
    );
  }
}
