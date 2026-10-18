import 'package:truce_core/truce_core.dart';

import '../../folders/note_folder.dart';
import '../note_place.dart';

/// The user's choice of where new notes go: a folder by id and one of
/// its subfolders, `null` for its top level. Kept by id, so it outlives
/// renames of the folder.
typedef NewNotePlaceSetting = ({String folderId, RelPath? subfolder});

/// [place] among [folders]: `null` if its folder is not one of them. Its
/// subfolder only if [subfoldersOf] the folder still lists it, so a
/// subfolder deleted meanwhile is never made again.
NotePlace? resolveNewNotePlace(
  NewNotePlaceSetting? place,
  List<NoteFolder> folders,
  List<RelPath> Function(NoteFolder folder) subfoldersOf,
) {
  if (place == null) return null;
  final folder = folders.where((f) => f.id == place.folderId).firstOrNull;
  if (folder == null) return null;
  final subfolder = place.subfolder;
  return (
    folder: folder,
    subfolder: subfolder != null && subfoldersOf(folder).contains(subfolder)
        ? subfolder
        : null,
  );
}
