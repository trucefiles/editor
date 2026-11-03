import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../files/files_wiring.dart';
import '../plugins/plugins_wiring.dart';
import '../storage/app_storage.dart';

final folderListStoreProvider = Provider<FolderListStore>(
  (ref) => FolderListStore(
    File('${ref.watch(appStorageProvider).settingsPath}/folders.json'),
  ),
);

/// The app's folder list owner, wired.
final folderListOwnerProvider = Provider<FolderListOwner>((ref) {
  final owner = folderListOwner(
    FolderListWork(
      store: ref.watch(folderListStoreProvider),
      plugins: ref.watch(folderPluginsProvider),
      secureOpen: ref.read(openFilesProvider).secureIn,
      forgetDrafts: (folder) => ref.read(draftsProvider).of(folder).forget(),
      countDrafts: (folder) => ref.read(draftsProvider).of(folder).count(),
    ),
  );
  ref.onDispose(() => unawaited(owner.close()));
  return owner;
});

final foldersProvider = AsyncNotifierProvider<FoldersController, List<Folder>>(
  FoldersController.new,
);

/// The folders added on this device, as the folder list owner shows them;
/// every change is saved before it shows. Loading while the list loads,
/// and still loading if it can't be read: nothing may act on folders it
/// doesn't know ([folderListStateProvider] tells the screens why).
class FoldersController extends AsyncNotifier<List<Folder>> {
  FolderListOwner get _owner => ref.read(folderListOwnerProvider);

  @override
  Future<List<Folder>> build() async {
    final owner = ref.watch(folderListOwnerProvider);
    final changes = owner.changes.listen((list) {
      if (list case FoldersLoaded(:final folders)) state = AsyncData(folders);
    });
    ref.onDispose(() => unawaited(changes.cancel()));
    return switch (await settledList(owner)) {
      FoldersLoaded(:final folders) => folders,
      FoldersUnreadable() ||
      FoldersLoading() => Completer<List<Folder>>().future,
    };
  }

  /// Adds the folders [candidates] name, from [plugin]'s add page, all
  /// together or none; the folders added.
  Future<Result<List<Folder>, FolderError>> add(
    FolderPlugin plugin,
    List<NamedCandidate> candidates,
  ) => answerOf(
    _owner,
    (ticket) => AddFolders(ticket, plugin: plugin.id, candidates: candidates),
    read: (FoldersAdded answer) => answer.result,
    orElse: const Err(FolderError.notSaved),
  );

  Future<Result<void, FolderError>> change(Folder changed) => answerOf(
    _owner,
    (ticket) => ChangeFolder(ticket, changed),
    read: (FolderChanged answer) => answer.result,
    orElse: const Err(FolderError.notSaved),
  );

  /// How many files have edits kept only on this device that
  /// removing [folder] would delete.
  Future<int> draftsLostByRemoving(Folder folder) => answerOf(
    _owner,
    (ticket) => CountDrafts(ticket, folder),
    read: (DraftsCounted answer) => answer.count,
    orElse: 0,
  );

  /// Moves [moved] to place [to] in the list (0 is first).
  Future<Result<void, FolderError>> move(Folder moved, {required int to}) =>
      answerOf(
        _owner,
        (ticket) => MoveFolder(ticket, moved, to: to),
        read: (FolderMoved answer) => answer.result,
        orElse: const Err(FolderError.notSaved),
      );

  /// Forgets the folder; its files stay untouched.
  Future<Result<void, FolderError>> remove(Folder removed) => answerOf(
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
