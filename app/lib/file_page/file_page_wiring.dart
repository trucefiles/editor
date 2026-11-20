import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

import '../app_end/app_end_wiring.dart';
import '../file_types/file_types.dart';
import '../files/file_actions.dart';
import '../files/file_settings_controller.dart';
import '../files/files_wiring.dart';
import '../folder_state/folder_state_controller.dart';
import '../reach/folder_reach_controller.dart';
import '../settings/device_settings_controller.dart';
import 'file_pages.dart';
import 'view_pages.dart';

/// Builds the page model of each open file. Watches only what never
/// changes, so a page can use it for as long as it is open; the rest is
/// read when asked.
final filePagesProvider = Provider<FilePages>(
  (ref) => FilePages(
    types: ref.watch(fileTypesProvider),
    create: _creator(ref),
    move: _mover(ref),
    delete: (file, bytes) => ref.read(fileActionsProvider).delete(file, bytes),
    settingsOf: (file) =>
        ref.read(fileSettingsProvider.notifier).settingsOf(file),
    editSettings: (file, change) =>
        ref.read(fileSettingsProvider.notifier).edit(file, change),
    filesOf: (folder) => TextFiles(ref.read(fileAccessProvider).of(folder)),
    draftsOf: (folder) => ref.read(draftsProvider).of(folder.id),
    reachOf: (folder) => ref.read(folderReachProvider(folder)),
    reachSettled: (folder) =>
        ref.read(folderReachProvider(folder).notifier).settled(),
    openEdits: ref.watch(openEditsProvider),
    endWait: appEndWait,
    arrivals: ref.watch(fileArrivalsProvider),
    fileClosed: () => _fileClosed(ref),
  ),
);

/// Builds the model of each view page; watches only what never changes,
/// as [filePagesProvider].
final viewPagesProvider = Provider<ViewPages>(
  (ref) => ViewPages(
    work: ShownWork(
      reload: (file) => ref.read(fileActionsProvider).read(file),
      draftsOf: (folder) => ref.read(draftsProvider).of(folder.id),
      create: _creator(ref),
      move: _mover(ref),
    ),
    delete: (file, bytes) => ref.read(fileActionsProvider).delete(file, bytes),
    settingsOf: (file) =>
        ref.read(fileSettingsProvider.notifier).settingsOf(file),
    editSettings: (file, change) =>
        ref.read(fileSettingsProvider.notifier).edit(file, change),
    reachOf: (folder) => ref.read(folderReachProvider(folder)),
    reachSettled: (folder) =>
        ref.read(folderReachProvider(folder).notifier).settled(),
    openEdits: ref.watch(openEditsProvider),
    endWait: appEndWait,
    fileClosed: () => _fileClosed(ref),
  ),
);

/// Creates files as the files owner does.
FileCreator _creator(Ref ref) =>
    (
      place, {
      required extension,
      required title,
      required bytes,
      newSubfolder = false,
    }) => ref
        .read(fileActionsProvider)
        .create(
          place,
          extension: extension,
          title: title,
          bytes: bytes,
          newSubfolder: newSubfolder,
        );

/// Moves files as the files owner does.
FileMover _mover(Ref ref) =>
    (file, place, {required title, required newSubfolder}) => ref
        .read(fileActionsProvider)
        .move(file, place, title: title, newSubfolder: newSubfolder);

/// Where nothing finds changes meanwhile, what shows next is listed
/// again once a page closes.
void _fileClosed(Ref ref) {
  final refresh = ref.read(deviceSettingsProvider).requireValue.refresh;
  if (refresh.listsWhenFileCloses) {
    unawaited(ref.read(folderContentsProvider.notifier).refresh());
  }
}
