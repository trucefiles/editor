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
    actions: () => ref.read(documentActionsProvider),
    settings: () => ref.read(documentSettingsProvider.notifier),
    filesOf: (folder) => ref.read(folderFilesProvider).of(folder),
    draftsOf: (folder) => ref.read(draftsProvider).of(folder.base.id),
    reachOf: (base) => ref.read(folderReachProvider(base)),
    reachSettled: (base) =>
        ref.read(folderReachProvider(base).notifier).settled(),
    openDocuments: ref.watch(openDocumentsProvider),
    refreshFolders: () => ref.read(folderContentsProvider.notifier).refresh(),
  ),
);
