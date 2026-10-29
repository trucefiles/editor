import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_documents/truce_documents.dart';

import '../../../folder_state/folder_state_controller.dart';
import '../../../folders/folders_controller.dart';
import '../../../folders/ui/folder_badge.dart';
import '../../../settings/device_settings_controller.dart';
import '../../document_actions.dart';
import '../../ui/document_place_dialog.dart';

/// Settings row with where new documents go; opens a dialog to pick a folder
/// and subfolder, and can go back to the default.
class NewFilePlaceTile extends ConsumerWidget {
  const NewFilePlaceTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider).value ?? const [];
    final setting = ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.newFilePlace),
    );
    ref.watch(folderContentsProvider);
    final actions = ref.read(documentActionsProvider);
    final place = resolveNewFilePlace(setting, folders);
    final device = ref.read(deviceSettingsProvider.notifier);
    return ListTile(
      enabled: folders.isNotEmpty,
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
              onPressed: () => device.change(
                (settings) => settings.copyWith(newFilePlace: () => null),
              ),
            ),
      onTap: () async {
        // Change events don't tell about new empty subfolders; a listing
        // finds them, so the dialog offers them.
        await ref.read(folderContentsProvider.notifier).refresh();
        if (!context.mounted) return;
        final picked = await showDocumentPlaceDialog(
          context,
          title: 'Default folder for new documents',
          action: 'OK',
          folders: folders,
          initial: place ?? topOf(folders.first),
          subfoldersOf: actions.subfoldersOf,
        );
        if (picked == null) return;
        await device.change(
          (settings) => settings.copyWith(
            newFilePlace: () =>
                (folderId: picked.folder.id, subfolder: picked.subfolder),
          ),
        );
      },
    );
  }
}
