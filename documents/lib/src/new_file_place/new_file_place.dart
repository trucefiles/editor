import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../document_place.dart';

/// The user's choice of where new documents go: a folder by id and one of
/// its subfolders, `null` for its top level. Kept by id, so it outlives
/// renames of the folder.
typedef NewFilePlaceSetting = ({String folderId, RelPath? subfolder});

/// [place] as JSON, e.g. `{"folder": "f1", "subfolder": "inbox"}`; `null`
/// for none chosen.
Object? newFilePlaceToJson(NewFilePlaceSetting? place) => switch (place) {
  (:final folderId, :final subfolder) => {
    'folder': folderId,
    if (subfolder != null) 'subfolder': subfolder.value,
  },
  null => null,
};

/// The place [json] holds; `null` if none, or not one written by
/// [newFilePlaceToJson].
NewFilePlaceSetting? newFilePlaceFromJson(Object? json) => switch (json) {
  {'folder': final String folderId, 'subfolder': final String raw} =>
    switch (RelPath.parse(raw)) {
      final subfolder? => (folderId: folderId, subfolder: subfolder),
      null => null,
    },
  {'folder': final String folderId} => (folderId: folderId, subfolder: null),
  _ => null,
};

/// [place] among [folders]: `null` if its folder is not one of them. Its
/// subfolder as set, also one a scan missed: creating the document checks it
/// (see `DocumentFiles.create`); the folder's top if the folder doesn't
/// show it any more.
DocumentPlace? resolveNewFilePlace(
  NewFilePlaceSetting? place,
  List<DocumentFolder> folders,
) {
  if (place == null) return null;
  final folder = folders.where((f) => f.id == place.folderId).firstOrNull;
  if (folder == null) return null;
  return showsPlace(folder, place.subfolder)
      ? (folder: folder, subfolder: place.subfolder)
      : topOf(folder);
}
