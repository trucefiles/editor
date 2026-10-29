import 'dart:math';

import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart';

import 'base_folder.dart';
import 'document_folder.dart';
import 'folder_error.dart';
import 'folder_list_contract.dart';
import 'folder_list_store.dart';
import 'host_paths.dart';

export 'folder_list_contract.dart';

/// The owner of the folders added on this device (see
/// `folder_list_contract.dart`).
typedef FolderListOwner =
    Owner<FolderListInput, FolderListState, FolderListAnswer>;

/// What the folder list owner works with, from the app's wiring.
final class FolderListWork {
  const FolderListWork({
    required this.store,
    required this.hostPaths,
    required this.isToolFolder,
    required this.secureOpen,
    required this.forgetDrafts,
    required this.countDrafts,
  });

  final FolderListStore store;

  /// Where base folders lie on the host, to tell whether they overlap.
  final HostPaths hostPaths;

  /// Whether the folder at an address belongs to a sync tool itself (e.g.
  /// its version folder).
  final bool Function(Uri address) isToolFolder;

  /// Keeps the edits of the documents open in a base folder where they
  /// last, before what the app may touch there changes.
  final Future<void> Function(BaseFolder base) secureOpen;

  /// Deletes the drafts of the documents of a base folder that [Selection]
  /// covers, as the user removes the folder that showed them.
  final Future<void> Function(BaseFolder base, Selection under) forgetDrafts;

  /// How many documents of a base folder that [Selection] covers have
  /// drafts.
  final Future<int> Function(BaseFolder base, Selection under) countDrafts;
}

/// The folder list owner: loads the saved list first, then runs each
/// change by [work]: checks it, keeps the open documents of a base folder
/// whose part shown changes, saves the new list, and only then shows it.
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
Future<List<DocumentFolder>> settledFolders(FolderListOwner owner) async =>
    switch (await settledList(owner)) {
      FoldersLoaded(:final folders) => folders,
      FoldersUnreadable() || FoldersLoading() => const [],
    };

final class _FolderListSteps {
  _FolderListSteps(this._work);

  final FolderListWork _work;
  final _random = Random.secure();

  Future<void> run(
    FolderListInput input,
    OwnerOutlet<FolderListState, FolderListAnswer> out,
  ) async => switch (input) {
    LoadFolders() => out.state = switch (await _work.store.load()) {
      Ok(:final value) => FoldersLoaded(value),
      Err(:final error) => FoldersUnreadable(error),
    },
    final FolderListAsking asking => out.emit(await _answer(asking, out)),
  };

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
      AddFolder(:final ticket) => FolderAdded(
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
      CountDraftsUnder(:final ticket, :final folder) => DraftsCounted(
        ticket,
        await _work.countDrafts(
          folder.base,
          _draftsGoneWith(folders ?? const [], folder),
        ),
      ),
    };
  }

  /// Refuses a folder of a sync tool's own, a base folder inside an added
  /// one or holding one (compared by host addresses, as a sandbox may show
  /// each at its own path), and a selection that clashes. Best effort in a
  /// sandbox: an address whose host address is unknown is checked as the
  /// sandbox shows it.
  Future<Result<DocumentFolder, FolderError>> _add(
    List<DocumentFolder> folders,
    AddFolder add,
    OwnerOutlet<FolderListState, FolderListAnswer> out,
  ) async {
    final host = await _work.hostPaths.of(add.address);
    if (_work.isToolFolder(host)) {
      return const Err(FolderError.syncToolInternal);
    }
    BaseFolder? same;
    for (final base in {for (final folder in folders) folder.base}) {
      final other = await _work.hostPaths.of(base.address);
      if (!_samePlace(host, other)) continue;
      if (_sameSegments.equals(_segments(other), _segments(host))) {
        same = base;
      } else if (_isWithin(host, other) || _isWithin(other, host)) {
        return const Err(FolderError.overlaps);
      }
    }
    final folder = DocumentFolder(
      id: _newId(),
      base:
          same ??
          BaseFolder(id: _newId(), address: add.address, toolId: add.toolId),
      selection: add.selection,
      name: add.name,
      color: add.color,
    );
    if (_clashes(folder, folders)) return const Err(FolderError.overlaps);
    return switch (await _save([...folders, folder], out)) {
      Ok() => Ok(folder),
      Err(:final error) => Err(error),
    };
  }

  Future<Result<void, FolderError>> _change(
    List<DocumentFolder> folders,
    DocumentFolder changed,
    OwnerOutlet<FolderListState, FolderListAnswer> out,
  ) async {
    final before = folders.where((f) => f.id == changed.id).firstOrNull;
    if (before == null) return const Ok(null);
    if (_clashes(changed, folders)) return const Err(FolderError.overlaps);
    if (changed.selection != before.selection) {
      await _work.secureOpen(before.base);
    }
    return _save([
      for (final folder in folders) folder.id == changed.id ? changed : folder,
    ], out);
  }

  /// Its drafts go once the list is saved: no edit is recovered into it.
  /// With its base folder's last folder, every draft of the base folder
  /// goes, also those no folder showed.
  Future<Result<void, FolderError>> _remove(
    List<DocumentFolder> folders,
    DocumentFolder removed,
    OwnerOutlet<FolderListState, FolderListAnswer> out,
  ) async {
    if (!folders.any((folder) => folder.id == removed.id)) {
      return const Ok(null);
    }
    final rest = [
      for (final folder in folders)
        if (folder.id != removed.id) folder,
    ];
    final dropped = _draftsGoneWith(folders, removed);
    await _work.secureOpen(removed.base);
    final saved = await _save(rest, out);
    if (saved is Ok) await _work.forgetDrafts(removed.base, dropped);
    return saved;
  }

  /// The drafts of its base folder that go with [removed]: those it
  /// shows, or all with the base folder's last folder.
  static Selection _draftsGoneWith(
    List<DocumentFolder> folders,
    DocumentFolder removed,
  ) =>
      folders.any(
        (folder) => folder.id != removed.id && folder.base == removed.base,
      )
      ? removed.selection
      : const WholeFolder();

  /// Saves [folders], then shows them.
  Future<Result<void, FolderError>> _save(
    List<DocumentFolder> folders,
    OwnerOutlet<FolderListState, FolderListAnswer> out,
  ) async {
    switch (await _work.store.save(folders)) {
      case Ok():
        out.state = FoldersLoaded(folders);
        return const Ok(null);
      case Err():
        return const Err(FolderError.notSaved);
    }
  }

  /// The one overlap rule: two folders clash when their parts of one base
  /// folder overlap (their file types, fixed for now, always do).
  static bool _clashes(DocumentFolder folder, List<DocumentFolder> folders) =>
      folders.any(
        (other) =>
            other.id != folder.id &&
            other.base.id == folder.base.id &&
            other.selection.overlaps(folder.selection),
      );

  static const _sameSegments = ListEquality<String>();

  static List<String> _segments(Uri address) => [
    for (final segment in address.pathSegments)
      if (segment.isNotEmpty) segment,
  ];

  /// Whether [a] and [b] can lie in one another: the same kind of place on
  /// the same host.
  static bool _samePlace(Uri a, Uri b) =>
      a.scheme == b.scheme && a.authority == b.authority;

  /// Whether the folder at [inner] lies inside the one at [outer].
  static bool _isWithin(Uri inner, Uri outer) {
    final (inside, around) = (_segments(inner), _segments(outer));
    return inside.length > around.length &&
        _sameSegments.equals(inside.sublist(0, around.length), around);
  }

  String _newId() =>
      List.generate(12, (_) => _random.nextInt(16).toRadixString(16)).join();
}
