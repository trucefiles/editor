import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart';

import 'folder.dart';
import 'folder_error.dart';
import 'folder_list_contract.dart';
import 'folder_list_store.dart';
import 'folder_plugins.dart';

export 'folder_list_contract.dart';

/// The owner of the folders added on this device (see
/// `folder_list_contract.dart`).
typedef FolderListOwner =
    Owner<FolderListInput, FolderListState, FolderListAnswer>;

/// What the folder list owner works with, from the app's wiring.
final class FolderListWork {
  const FolderListWork({
    required this.store,
    required this.plugins,
    required this.secureOpen,
    required this.forgetDrafts,
    required this.countDrafts,
  });

  final FolderListStore store;

  /// The plugins, each with its state, which the owner saves with its
  /// list.
  final FolderPlugins plugins;

  /// Keeps the edits of the files open in a folder where they last,
  /// before the folder goes.
  final Future<void> Function(FolderId folder) secureOpen;

  /// Deletes the drafts of a folder's files, as the user removes it.
  final Future<void> Function(FolderId folder) forgetDrafts;

  /// How many of a folder's files have drafts.
  final Future<int> Function(FolderId folder) countDrafts;
}

/// The folder list owner: loads the saved list and every plugin's state
/// first, then runs each change by [work]: the plugin's state changes,
/// then the list and every plugin's state are saved in one write, and
/// only then shown. A save that fails gives the plugin its state back:
/// nothing changed.
FolderListOwner folderListOwner(FolderListWork work) {
  final owner = SimpleOwner<FolderListInput, FolderListState, FolderListAnswer>(
    const FoldersLoading(),
    _FolderListSteps(work).run,
  );
  owner.send(const LoadFolders());
  return owner;
}

/// [owner]'s list once it is no longer loading; still loading if the
/// owner ended before.
Future<FolderListState> settledList(FolderListOwner owner) async =>
    owner.state is FoldersLoading
    ? await owner.changes.firstWhere(
        (list) => list is! FoldersLoading,
        orElse: () => owner.state,
      )
    : owner.state;

/// The folders once [owner]'s list has loaded; none if it can't be read or
/// the owner ended before, so a caller that must go on goes on with
/// nothing to act on.
Future<List<Folder>> settledFolders(FolderListOwner owner) async =>
    switch (await settledList(owner)) {
      FoldersLoaded(:final folders) => folders,
      FoldersUnreadable() || FoldersLoading() => const [],
    };

final class _FolderListSteps {
  _FolderListSteps(this._work);

  final FolderListWork _work;

  List<FolderPlugin> get _plugins => _work.plugins.all;

  Future<void> run(
    FolderListInput input,
    OwnerOutlet<FolderListState, FolderListAnswer> out,
  ) async => switch (input) {
    LoadFolders() => out.state = await _load(),
    final FolderListAsking asking => out.emit(await _answer(asking, out)),
  };

  /// The saved list, with every plugin's state loaded from it. A list
  /// and plugins that disagree, or a plugin state that can't be read,
  /// make the list unreadable: then no plugin holds a folder.
  Future<FolderListState> _load() async {
    final saved = await _work.store.load();
    final folders = switch (saved) {
      Ok(:final value) => _loaded(value),
      Err() => null,
    };
    if (folders != null) return FoldersLoaded(folders);
    for (final plugin in _plugins) {
      plugin.load(null);
    }
    return FoldersUnreadable(switch (saved) {
      Err(:final error) => error,
      Ok() => SettingsError.corrupt,
    });
  }

  List<Folder>? _loaded(SavedFolders saved) {
    final read = [
      for (final plugin in _plugins) plugin.load(saved.blobs[plugin.id]),
    ];
    if (read.contains(false) ||
        !saved.blobs.keys.every((id) => _work.plugins.byId(id) != null)) {
      return null;
    }
    final locations = {
      for (final plugin in _plugins)
        for (final folder in plugin.folders)
          FolderId(plugin.id, folder.id): folder.location,
    };
    final ids = [for (final entry in saved.folders) entry.id];
    if (!const UnorderedIterableEquality<FolderId>().equals(
          ids,
          locations.keys,
        ) ||
        ids.toSet().length != ids.length) {
      return null;
    }
    return [
      for (final entry in saved.folders)
        Folder(
          id: entry.id,
          name: entry.name,
          color: entry.color,
          location: locations[entry.id]!,
        ),
    ];
  }

  Future<FolderListAnswer> _answer(
    FolderListAsking input,
    OwnerOutlet<FolderListState, FolderListAnswer> out,
  ) async {
    final folders = switch (out.state) {
      FoldersLoaded(:final folders) => folders,
      // Never changed: saving would write over the list that failed to
      // load.
      FoldersLoading() || FoldersUnreadable() => null,
    };
    const unsaved = Err<Never, FolderError>(FolderError.notSaved);
    return switch (input) {
      AddFolders(:final ticket) => FoldersAdded(
        ticket,
        folders == null ? unsaved : await _add(folders, input, out),
      ),
      ChangeFolder(:final ticket, :final changed) => FolderChanged(
        ticket,
        folders == null ? unsaved : await _change(folders, changed, out),
      ),
      RemoveFolder(:final ticket, :final removed) => FolderRemoved(
        ticket,
        folders == null ? unsaved : await _remove(folders, removed, out),
      ),
      CountDrafts(:final ticket, :final folder) => DraftsCounted(
        ticket,
        await _work.countDrafts(folder.id),
      ),
    };
  }

  Future<Result<List<Folder>, FolderError>> _add(
    List<Folder> folders,
    AddFolders add,
    OwnerOutlet<FolderListState, FolderListAnswer> out,
  ) async {
    final plugin = _work.plugins.of(add.plugin);
    final before = plugin.blob;
    switch (plugin.add([for (final named in add.candidates) named.candidate])) {
      case Err():
        return const Err(FolderError.overlaps);
      case Ok(value: final set):
        final added = [
          for (final (index, folder) in set.indexed)
            Folder(
              id: FolderId(plugin.id, folder.id),
              name: add.candidates[index].name,
              color: add.candidates[index].color,
              location: folder.location,
            ),
        ];
        return switch (await _save([...folders, ...added], out)) {
          Ok() => Ok(added),
          Err(:final error) => _undone(plugin, before, error),
        };
    }
  }

  Future<Result<void, FolderError>> _change(
    List<Folder> folders,
    Folder changed,
    OwnerOutlet<FolderListState, FolderListAnswer> out,
  ) async {
    if (folders.byId(changed.id) == null) return const Ok(null);
    return _save([
      for (final folder in folders) folder.id == changed.id ? changed : folder,
    ], out);
  }

  /// Secures its open files first; its drafts go once the list is saved,
  /// so no edit is recovered into it.
  Future<Result<void, FolderError>> _remove(
    List<Folder> folders,
    Folder removed,
    OwnerOutlet<FolderListState, FolderListAnswer> out,
  ) async {
    if (folders.byId(removed.id) == null) return const Ok(null);
    await _work.secureOpen(removed.id);
    final plugin = _work.plugins.of(removed.id.plugin);
    final before = plugin.blob;
    plugin.forget(removed.id.folder);
    final saved = await _save([
      for (final folder in folders)
        if (folder.id != removed.id) folder,
    ], out);
    if (saved case Err(:final error)) return _undone(plugin, before, error);
    await _work.forgetDrafts(removed.id);
    return const Ok(null);
  }

  /// Gives [plugin] its state [before] back, as the save failed.
  Err<T, FolderError> _undone<T>(
    FolderPlugin plugin,
    Object? before,
    FolderError error,
  ) {
    plugin.load(before);
    return Err(error);
  }

  /// Saves [folders] with every plugin's state, then shows them.
  Future<Result<void, FolderError>> _save(
    List<Folder> folders,
    OwnerOutlet<FolderListState, FolderListAnswer> out,
  ) async {
    final saved = await _work.store.save((
      folders: [
        for (final folder in folders)
          (id: folder.id, name: folder.name, color: folder.color),
      ],
      blobs: {for (final plugin in _plugins) plugin.id: plugin.blob},
    ));
    switch (saved) {
      case Ok():
        out.state = FoldersLoaded(folders);
        return const Ok(null);
      case Err():
        return const Err(FolderError.notSaved);
    }
  }
}
