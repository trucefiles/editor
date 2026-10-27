import 'package:truce_core/truce_core.dart';

import '../../folders/document_folder.dart';
import '../document_place.dart';

/// The user's choice of where new documents go: a folder by id and one of
/// its subfolders, `null` for its top level. Kept by id, so it outlives
/// renames of the folder.
typedef NewNotePlaceSetting = ({String folderId, RelPath? subfolder});

/// [place] among [folders]: `null` if its folder is not one of them. Its
/// subfolder as set, also one a scan missed: creating the document checks it
/// (see `DocumentFiles.create`).
DocumentPlace? resolveNewNotePlace(
  NewNotePlaceSetting? place,
  List<DocumentFolder> folders,
) {
  if (place == null) return null;
  final folder = folders.where((f) => f.id == place.folderId).firstOrNull;
  if (folder == null) return null;
  return (folder: folder, subfolder: place.subfolder);
}
