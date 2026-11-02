import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../file_types/file_types.dart';
import '../files/file_actions.dart';
import '../files/file_settings_controller.dart';
import '../files/files_wiring.dart';
import '../folder_state/folder_state_controller.dart';
import '../reach/folder_reach_controller.dart';
import 'file_pages.dart';

/// Builds the page model of each open file. Watches only what never
/// changes, so a page can use it for as long as it is open; the rest is
/// read when asked.
final filePagesProvider = Provider<FilePages>(
  (ref) => FilePages(
    types: ref.watch(fileTypesProvider),
    create:
        (
          place, {
          required type,
          required title,
          required text,
          newSubfolder = false,
        }) => ref
            .read(fileActionsProvider)
            .create(
              place,
              type: type,
              title: title,
              text: text,
              newSubfolder: newSubfolder,
            ),
    move: (file, place, {required title, required newSubfolder}) => ref
        .read(fileActionsProvider)
        .move(file, place, title: title, newSubfolder: newSubfolder),
    delete: (file, text) => ref.read(fileActionsProvider).delete(file, text),
    settingsOf: (file) =>
        ref.read(fileSettingsProvider.notifier).settingsOf(file),
    editSettings: (file, change) =>
        ref.read(fileSettingsProvider.notifier).edit(file, change),
    filesOf: (folder) => ref.read(folderFilesProvider).of(folder),
    draftsOf: (folder) => ref.read(draftsProvider).of(folder.base.id),
    reachOf: (base) => ref.read(folderReachProvider(base)),
    reachSettled: (base) =>
        ref.read(folderReachProvider(base).notifier).settled(),
    openFiles: ref.watch(openFilesProvider),
    refreshFolders: () => ref.read(folderContentsProvider.notifier).refresh(),
  ),
);
