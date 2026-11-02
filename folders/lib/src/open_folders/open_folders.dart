import 'dart:async';

import 'package:truce_core/truce_core.dart';

import '../folder.dart';
import '../folder_list_owner.dart';
import '../folder_plugins.dart';
import 'folder_services.dart';

/// Builds the services of [folder] on [raw], its plugin's raw access to
/// it, telling [reach] how each access goes.
typedef BuildServices = FolderServices Function(
  Folder folder,
  RawFolder raw,
  FolderReach reach,
);

/// The folders the folder list shows, opened: each folder's services,
/// opened by its plugin at the first ask, and closed as the folder goes
/// from the list (its reach ends too) or the app ends. Follows the folder
/// list owner's state.
///
/// A folder that went keeps its closed services: whoever still holds it,
/// e.g. a screen about to close, gets [StoreError.closed].
final class OpenFolders {
  OpenFolders(this._folders, {required this._plugins, required this._build}) {
    _listening = _folders.changes.listen((_) => _follow());
  }

  final FolderListOwner _folders;
  final FolderPlugins _plugins;
  final BuildServices _build;
  late final StreamSubscription<FolderListState> _listening;

  /// The open folders, by id.
  final _open = <FolderId, FolderServices>{};

  /// The closed services of folders that went, by id; kept until the app
  /// ends.
  final _gone = <FolderId, FolderServices>{};

  final _changes = StreamController<void>.broadcast(sync: true);

  /// Fires each time a folder's services close.
  Stream<void> get changes => _changes.stream;

  /// The services of the folder [id], one the list shows or showed.
  FolderServices servicesOf(FolderId id) {
    _follow();
    if (_open[id] ?? _gone[id] case final services?) return services;
    final folder =
        _shown.byId(id) ?? (throw StateError('No folder $id is shown'));
    final raw = _plugins.of(id.plugin).open(id.folder);
    return _open[id] = _build(folder, raw, folderReach(raw.files));
  }

  /// Closes every folder; done once the work under way is.
  Future<void> close() async {
    await _listening.cancel();
    await Future.wait([..._open.values.map(_closed)]);
    _open.clear();
    await _changes.close();
  }

  List<Folder> get _shown => switch (_folders.state) {
    FoldersLoaded(:final folders) => folders,
    FoldersLoading() || FoldersUnreadable() => const <Folder>[],
  };

  /// Closes the folders the list no longer shows. Run at every change,
  /// and before every answer, so no answer is ever older than the list,
  /// whoever heard of the change first.
  void _follow() {
    final shown = {for (final folder in _shown) folder.id};
    final gone = [
      for (final id in _open.keys)
        if (!shown.contains(id)) id,
    ];
    for (final id in gone) {
      final services = _gone[id] = _open.remove(id)!;
      unawaited(_closed(services));
    }
    if (gone.isNotEmpty && !_changes.isClosed) _changes.add(null);
  }

  static Future<void> _closed(FolderServices services) async {
    await services.open.close();
    await services.reach.close();
  }
}
