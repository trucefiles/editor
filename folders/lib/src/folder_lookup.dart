import 'package:truce_core/truce_core.dart';

import 'base_folder.dart';
import 'document_folder.dart';

/// Questions on the folders added on this device.
extension FolderLookup on Iterable<DocumentFolder> {
  /// Everything the folders show of [base]: what the app may touch there;
  /// nothing once no folder shows it.
  Selection selectionOf(BaseFolder base) => where(
    (folder) => folder.base == base,
  ).fold(Selection.nothing, (all, folder) => all.union(folder.selection));

  /// The folder that shows the file at [path] in the base folder
  /// [baseId]; `null` if none does (e.g. a key kept from before a folder
  /// changed). At most one does, by the overlap rule.
  DocumentFolder? folderOf(String baseId, RelPath path) =>
      where((folder) => folder.base.id == baseId && folder.covers(path))
          .firstOrNull;
}
