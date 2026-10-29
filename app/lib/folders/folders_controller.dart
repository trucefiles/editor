import 'dart:async';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../document_page/open_documents.dart';
import '../documents/document_drafts.dart';
import '../platform/platform_wiring.dart';
import '../storage/app_storage.dart';
import '../sync_tool/sync_tools.dart';
import 'document_folder.dart';
import 'folder_error.dart';
import 'folder_list_owner.dart';
import 'folder_list_store.dart';

final folderListStoreProvider = Provider<FolderListStore>(
  (ref) => FolderListStore(
    File('${ref.watch(appStorageProvider).settingsPath}/folder_list.json'),
    toolIds: {for (final tool in ref.watch(syncToolsProvider).all) tool.id},
  ),
);

/// The app's folder list owner, wired.
final folderListOwnerProvider = Provider<FolderListOwner>((ref) {
  final owner = folderListOwner(
    FolderListWork(
      store: ref.watch(folderListStoreProvider),
      hostPaths: ref.watch(hostPathsProvider),
      isToolFolder: ref.watch(syncToolsProvider).isToolFolder,
      secureOpen: ref.read(openDocumentsProvider).secureIn,
      forgetDrafts: (base, under) =>
          ref.read(documentDraftsProvider(base.id)).removeUnder(under),
    ),
  );
  ref.onDispose(() => unawaited(owner.close()));
  return owner;
});

final foldersProvider = NotifierProvider<FoldersController, FolderListState>(
  FoldersController.new,
);

/// The folders added on this device, once loaded. Waits while the list
/// loads, and keeps waiting if it can't be read: nothing may act on
/// folders it doesn't know (the home screen tells the user instead).
final loadedFoldersProvider = FutureProvider<List<DocumentFolder>>(
  (ref) => switch (ref.watch(foldersProvider)) {
    FoldersLoaded(:final folders) => folders,
    FoldersLoading() ||
    FoldersUnreadable() => Completer<List<DocumentFolder>>().future,
  },
);

/// The folder list as its owner shows it; every change is saved before
/// it shows.
class FoldersController extends Notifier<FolderListState> {
  FolderListOwner get _owner => ref.read(folderListOwnerProvider);

  @override
  FolderListState build() {
    final owner = ref.watch(folderListOwnerProvider);
    final changes = owner.changes.listen((list) => state = list);
    ref.onDispose(() => unawaited(changes.cancel()));
    return owner.state;
  }

  /// Adds a folder showing [selection] of the base folder at [address],
  /// synced by the tool [toolId]; the folder added.
  Future<Result<DocumentFolder, FolderError>> add({
    required Uri address,
    required String toolId,
    required Selection selection,
    required String name,
    required Color color,
  }) async => switch (await _ask<FolderAdded>(
    (ticket) => AddFolder(
      ticket,
      address: address,
      toolId: toolId,
      selection: selection,
      name: name,
      color: color,
    ),
  )) {
    final answer? => answer.result,
    null => const Err(FolderError.notSaved),
  };

  Future<Result<void, FolderError>> change(DocumentFolder changed) async =>
      switch (await _ask<FolderChanged>(
        (ticket) => ChangeFolder(ticket, changed),
      )) {
        final answer? => answer.result,
        null => const Err(FolderError.notSaved),
      };

  /// Forgets the folder; its files stay untouched.
  Future<Result<void, FolderError>> remove(DocumentFolder removed) async =>
      switch (await _ask<FolderRemoved>(
        (ticket) => RemoveFolder(ticket, removed),
      )) {
        final answer? => answer.result,
        null => const Err(FolderError.notSaved),
      };

  /// The owner's answer to [asking]; `null` once it ended.
  Future<A?> _ask<A extends FolderListAnswer>(
    FolderListInput Function(Ticket ticket) asking,
  ) => ask<FolderListInput, A>(_owner.send, _owner.events, asking);
}
