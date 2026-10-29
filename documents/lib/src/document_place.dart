import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/document_folder.dart';

/// Where a document goes: a folder and a subfolder of its base folder that
/// it shows, `null` for the base folder's top level (only for a folder
/// that shows the whole base folder).
typedef DocumentPlace = ({DocumentFolder folder, RelPath? subfolder});

/// The top of [folder]: its base folder's top level, or, for a folder of
/// some subfolders, the first of them by path.
DocumentPlace topOf(DocumentFolder folder) => (
  folder: folder,
  subfolder: switch (folder.selection) {
    WholeFolder() => null,
    Subfolders(:final roots) =>
      roots.sorted((a, b) => a.value.compareTo(b.value)).firstOrNull,
  },
);

/// Whether [folder] shows the documents placed in [subfolder].
bool showsPlace(DocumentFolder folder, RelPath? subfolder) => subfolder == null
    ? folder.selection is WholeFolder
    : folder.covers(subfolder);
