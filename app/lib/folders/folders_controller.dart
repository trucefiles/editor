import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../documents/documents_wiring.dart';
import '../platform/platform_wiring.dart';
import '../storage/app_storage.dart';
import '../sync_tool/sync_tools_wiring.dart';

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
          ref.read(draftsProvider).of(base.id).removeUnder(under),
    ),
  );
  ref.onDispose(() => unawaited(owner.close()));
  return owner;
});

final foldersProvider =
    AsyncNotifierProvider<FoldersController, List<DocumentFolder>>(
      FoldersController.new,
    );

/// The folders added on this device, as the folder list owner shows them;
/// every change is saved before it shows. Loading while the list loads,
/// and still loading if it can't be read: nothing may act on folders it
/// doesn't know ([folderListStateProvider] tells the screens why).
class FoldersController extends AsyncNotifier<List<DocumentFolder>> {
  FolderListOwner get _owner => ref.read(folderListOwnerProvider);

  @override
  Future<List<DocumentFolder>> build() async {
    final owner = ref.watch(folderListOwnerProvider);
    final changes = owner.changes.listen((list) {
      if (list case FoldersLoaded(:final folders)) state = AsyncData(folders);
    });
    ref.onDispose(() => unawaited(changes.cancel()));
    return switch (await settledList(owner)) {
      FoldersLoaded(:final folders) => folders,
      FoldersUnreadable() ||
      FoldersLoading() => Completer<List<DocumentFolder>>().future,
    };
  }

  /// Adds a folder showing [selection] of the base folder at [address],
  /// synced by the tool [toolId]; the folder added.
  Future<Result<DocumentFolder, FolderError>> add({
    required Uri address,
    required String toolId,
    required Selection selection,
    required String name,
    required String color,
  }) => answerOf(
    _owner,
    (ticket) => AddFolder(
      ticket,
      address: address,
      toolId: toolId,
      selection: selection,
      name: name,
      color: color,
    ),
    read: (FolderAdded answer) => answer.result,
    orElse: const Err(FolderError.notSaved),
  );

  Future<Result<void, FolderError>> change(DocumentFolder changed) => answerOf(
    _owner,
    (ticket) => ChangeFolder(ticket, changed),
    read: (FolderChanged answer) => answer.result,
    orElse: const Err(FolderError.notSaved),
  );

  /// Forgets the folder; its files stay untouched.
  Future<Result<void, FolderError>> remove(DocumentFolder removed) => answerOf(
    _owner,
    (ticket) => RemoveFolder(ticket, removed),
    read: (FolderRemoved answer) => answer.result,
    orElse: const Err(FolderError.notSaved),
  );
}

final folderListStateProvider =
    NotifierProvider<FolderListStateController, FolderListState>(
      FolderListStateController.new,
    );

/// The folder list owner's state as it changes, for the screens: still
/// loading, loaded, or unreadable and why.
class FolderListStateController extends Notifier<FolderListState> {
  @override
  FolderListState build() {
    final owner = ref.watch(folderListOwnerProvider);
    final changes = owner.changes.listen((list) => state = list);
    ref.onDispose(() => unawaited(changes.cancel()));
    return owner.state;
  }
}
