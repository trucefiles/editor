import '../common/result.dart';
import 'file_store.dart';
import 'rel_path.dart';

/// Which folders a [FileStore] has.
extension FoldersThere on FileStore {
  /// Those of [folders] that are there, by one listing that walks only the
  /// way to them. One on an unreadable way counts as there: nothing tells
  /// it is gone. Fails as the listing does, e.g. if the root is gone.
  Future<Result<Set<RelPath>, StoreError>> foldersThere(
    Set<RelPath> folders,
  ) async {
    final listed = await list(
      enterFolder: (folder) =>
          folders.any((wanted) => wanted.isAtOrInside(folder)),
      includeFile: (_) => false,
    );
    return switch (listed) {
      Ok(value: final listing) => Ok({
        for (final folder in folders)
          if (listing.folders.contains(folder) ||
              listing.unreadable.any(folder.isAtOrInside))
            folder,
      }),
      Err(:final error) => Err(error),
    };
  }
}
