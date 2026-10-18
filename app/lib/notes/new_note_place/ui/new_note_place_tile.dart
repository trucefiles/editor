import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../folders/folders_controller.dart';
import '../../../folders/ui/folder_badge.dart';
import '../../../scan/folder_scans_controller.dart';
import '../../note_actions.dart';
import '../../ui/note_place_dialog.dart';
import '../new_note_place_controller.dart';

/// Settings row with where new notes go; opens a dialog to pick a folder
/// and subfolder, and can go back to the default.
class NewNotePlaceTile extends ConsumerWidget {
  const NewNotePlaceTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider).value ?? const [];
    final setting = ref.watch(newNotePlaceProvider);
    ref.watch(folderScansProvider);
    final actions = ref.read(noteActionsProvider);
    // As set, also a subfolder the last scan missed (e.g. while the
    // folder can't be reached): new notes check it as they go there.
    final place = switch (setting.value) {
      (:final folderId, :final subfolder) => switch (folders
          .where((folder) => folder.id == folderId)
          .firstOrNull) {
        final folder? => (folder: folder, subfolder: subfolder),
        null => null,
      },
      null => null,
    };
    return ListTile(
      enabled: setting.hasValue && folders.isNotEmpty,
      title: const Text('New notes go to'),
      subtitle: place == null
          ? const Text('The folder shown, else the one used last')
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
                  ref.read(newNotePlaceProvider.notifier).set(null),
            ),
      onTap: () async {
        // Change events don't tell about new empty subfolders; a rescan
        // finds them, so the dialog offers them.
        await ref.read(folderScansProvider.notifier).refresh();
        if (!context.mounted) return;
        final picked = await showNotePlaceDialog(
          context,
          title: 'New notes go to',
          action: 'OK',
          folders: folders,
          initial: place ?? (folder: folders.first, subfolder: null),
          subfoldersOf: actions.subfoldersOf,
        );
        if (picked == null) return;
        await ref.read(newNotePlaceProvider.notifier).set((
          folderId: picked.folder.id,
          subfolder: picked.subfolder,
        ));
      },
    );
  }
}
