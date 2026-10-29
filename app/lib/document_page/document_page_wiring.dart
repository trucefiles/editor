import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../documents/document_actions.dart';
import '../documents/document_settings_controller.dart';
import '../documents/documents_wiring.dart';
import '../file_types/document_types.dart';
import '../folder_state/folder_state_controller.dart';
import '../reach/folder_reach_controller.dart';
import 'document_pages.dart';

/// Builds the page model of each open document. Watches only what never
/// changes, so a page can use it for as long as it is open; the rest is
/// read when asked.
final documentPagesProvider = Provider<DocumentPages>(
  (ref) => DocumentPages(
    types: ref.watch(documentTypesProvider),
    create:
        (
          place, {
          required type,
          required title,
          required text,
          newSubfolder = false,
        }) => ref
            .read(documentActionsProvider)
            .create(
              place,
              type: type,
              title: title,
              text: text,
              newSubfolder: newSubfolder,
            ),
    move: (document, place, {required title, required newSubfolder}) => ref
        .read(documentActionsProvider)
        .move(document, place, title: title, newSubfolder: newSubfolder),
    delete: (document, text) =>
        ref.read(documentActionsProvider).delete(document, text),
    settingsOf: (document) =>
        ref.read(documentSettingsProvider.notifier).settingsOf(document),
    editSettings: (document, change) =>
        ref.read(documentSettingsProvider.notifier).edit(document, change),
    filesOf: (folder) => ref.read(folderFilesProvider).of(folder),
    draftsOf: (folder) => ref.read(draftsProvider).of(folder.base.id),
    reachOf: (base) => ref.read(folderReachProvider(base)),
    reachSettled: (base) =>
        ref.read(folderReachProvider(base).notifier).settled(),
    openDocuments: ref.watch(openDocumentsProvider),
    refreshFolders: () => ref.read(folderContentsProvider.notifier).refresh(),
  ),
);
