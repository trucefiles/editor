import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../document_page/open_documents.dart';
import '../file_types/document_types.dart';
import '../folder_state/folder_state_controller.dart';
import '../folders/folder_list_owner.dart';
import '../folders/folders_controller.dart';
import '../storage/app_storage.dart';
import '../sync_tool/base_folder_wiring.dart';
import 'document_drafts.dart';
import 'document_files.dart';
import 'document_settings_controller.dart';
import 'document_steps.dart';
import 'documents_owner.dart';

/// The document files of every folder.
final folderFilesProvider = Provider<FolderFiles>(
  (ref) => FolderFiles(
    ref.watch(baseFolderStacksProvider).servicesOf,
    ref.watch(documentTypesProvider),
  ),
);

/// The drafts of every base folder, in app storage.
final draftsProvider = Provider<DraftsByBase>(
  (ref) => DraftsByBase(ref.watch(appStorageProvider).draftsPath),
);

/// The documents open on screen right now.
final openDocumentsProvider = Provider<OpenDocuments>((_) => OpenDocuments());

/// What the document steps work with.
final documentsWorkProvider = Provider<DocumentsWork>((ref) {
  final folderList = ref.watch(folderListOwnerProvider);
  return DocumentsWork(
    files: ref.watch(folderFilesProvider),
    servicesOf: ref.watch(baseFolderStacksProvider).servicesOf,
    settings: ref.watch(documentSettingsProvider.notifier),
    // None known once the app ends.
    conflictWaits: (key) =>
        ref.mounted &&
        ref.read(folderContentsProvider).value?.conflicts.forDocument(key) !=
            null,
    folders: () => settledFolders(folderList),
    drafts: ref.watch(draftsProvider),
    types: ref.watch(documentTypesProvider),
  );
});

final documentStepsProvider = Provider<DocumentSteps>(
  (ref) => DocumentSteps(ref.watch(documentsWorkProvider)),
);

/// The app's documents owner. Outlives every screen, so an undo still
/// works after the editor closed; recovers the drafts of the last run
/// first.
final documentsProvider = Provider<Documents>((ref) {
  final documents = startDocuments(
    ref.watch(documentStepsProvider),
    startedAt: DateTime.now(),
  );
  ref.onDispose(() => unawaited(documents.owner.close()));
  return documents;
});
