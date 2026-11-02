import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../file_types/file_types.dart';
import '../folder_state/folder_state_wiring.dart';
import '../folders/folders_controller.dart';
import '../storage/app_storage.dart';
import '../sync_tool/base_folder_wiring.dart';
import 'file_settings_controller.dart';

/// The files of every folder.
final fileAccessProvider = Provider<FileAccess>(
  (ref) => FileAccess(
    ref.watch(baseFolderStacksProvider).servicesOf,
    ref.watch(fileTypesProvider),
  ),
);

/// The drafts of every base folder, in app storage.
final draftsProvider = Provider<DraftsByBase>(
  (ref) => DraftsByBase(ref.watch(appStorageProvider).draftsPath),
);

/// The files open on screen right now.
final openFilesProvider = Provider<OpenFiles>((_) => OpenFiles());

/// What the file steps work with.
final filesWorkProvider = Provider<FilesWork>((ref) {
  final folderList = ref.watch(folderListOwnerProvider);
  final folderState = ref.watch(folderStateOwnerProvider);
  return FilesWork(
    files: ref.watch(fileAccessProvider),
    servicesOf: ref.watch(baseFolderStacksProvider).servicesOf,
    settings: ref.watch(fileSettingsProvider.notifier),
    conflictWaits: (key) => conflictWaitsIn(folderState.state, key),
    folders: () => settledFolders(folderList),
    drafts: ref.watch(draftsProvider),
    types: ref.watch(fileTypesProvider),
  );
});

final fileStepsProvider = Provider<FileSteps>(
  (ref) => FileSteps(ref.watch(filesWorkProvider)),
);

/// The app's files owner. Outlives every screen, so an undo still
/// works after the editor closed; recovers the drafts of the last run
/// first.
final filesProvider = Provider<Files>((ref) {
  final files = startFiles(
    ref.watch(fileStepsProvider),
    startedAt: DateTime.now(),
  );
  ref.onDispose(() => unawaited(files.owner.close()));
  return files;
});
