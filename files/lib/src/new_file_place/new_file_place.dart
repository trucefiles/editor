import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../file_place.dart';

/// The user's choice of where new files go: a folder by id and one of
/// its subfolders, `null` for its top level. Kept by id, so it outlives
/// renames of the folder.
typedef NewFilePlaceSetting = ({FolderId folderId, RelPath? subfolder});

/// [place] as JSON, e.g.
/// `{"plugin": "syncthing", "folder": "f1", "subfolder": "inbox"}`; `null`
/// for none chosen.
Object? newFilePlaceToJson(NewFilePlaceSetting? place) => switch (place) {
  (:final folderId, :final subfolder) => {
    'plugin': folderId.plugin,
    'folder': folderId.folder,
    if (subfolder != null) 'subfolder': subfolder.value,
  },
  null => null,
};

/// The place [json] holds; `null` if none, or not one written by
/// [newFilePlaceToJson].
NewFilePlaceSetting? newFilePlaceFromJson(Object? json) => switch (json) {
  {
    'plugin': final String plugin,
    'folder': final String folder,
    'subfolder': final String raw,
  } =>
    switch (RelPath.parse(raw)) {
      final subfolder? => (
        folderId: FolderId(plugin, folder),
        subfolder: subfolder,
      ),
      null => null,
    },
  {'plugin': final String plugin, 'folder': final String folder} => (
    folderId: FolderId(plugin, folder),
    subfolder: null,
  ),
  _ => null,
};

/// [place] among [folders]: `null` if its folder is not one of them. Its
/// subfolder as set, also one a scan missed: creating the file checks it
/// and falls back to the folder's top (see `FilesOfFolder.create`).
FilePlace? resolveNewFilePlace(
  NewFilePlaceSetting? place,
  List<Folder> folders,
) {
  if (place == null) return null;
  final folder = folders.where((f) => f.id == place.folderId).firstOrNull;
  if (folder == null) return null;
  return (folder: folder, subfolder: place.subfolder);
}

/// Where a new file goes among [reachable], the folders that can be
/// reached now, in the user's order: the place the user [set] for new
/// files if its folder is one of them, else the first of them the home
/// grid is [filtered] to, else the first; `null` if none can be reached.
FilePlace? newFilePlaceIn(
  List<Folder> reachable, {
  required NewFilePlaceSetting? set,
  required Set<FolderId> filtered,
}) =>
    resolveNewFilePlace(set, reachable) ??
    switch (reachable.where((f) => filtered.contains(f.id)).firstOrNull ??
        reachable.firstOrNull) {
      final folder? => topOf(folder),
      null => null,
    };
