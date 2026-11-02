import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

/// Where a file goes: a folder and a subfolder of its base folder that
/// it shows, `null` for the base folder's top level (only for a folder
/// that shows the whole base folder).
typedef FilePlace = ({Folder folder, RelPath? subfolder});

/// The top of [folder]: its base folder's top level, or, for a folder of
/// some subfolders, the first of them by path.
FilePlace topOf(Folder folder) => (
  folder: folder,
  subfolder: switch (folder.selection) {
    WholeFolder() => null,
    Subfolders(:final roots) =>
      roots.sorted((a, b) => a.value.compareTo(b.value)).firstOrNull,
  },
);

/// Whether [folder] shows the files placed in [subfolder].
bool showsPlace(Folder folder, RelPath? subfolder) => subfolder == null
    ? folder.selection is WholeFolder
    : folder.covers(subfolder);
