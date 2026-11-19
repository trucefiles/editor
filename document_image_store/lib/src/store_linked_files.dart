import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import 'document_image_store.dart';
import 'image_names.dart';

/// The document images as `files` sees them ([LinkedFiles]): each
/// folder's [DocumentImageStore], by [_storeOf]. A link is ours only if
/// its name is ours and its image is in the folder's store; any other is
/// never touched.
final class StoreLinkedFiles implements LinkedFiles {
  const StoreLinkedFiles(this._storeOf);

  final DocumentImageStore Function(Folder folder) _storeOf;

  @override
  Future<Result<void, StoreError>> copyFor(
    String text, {
    required Folder from,
    required Folder to,
  }) => _storeOf(from).copyInto(_storeOf(to), ImageNames.namesIn(text));

  /// Links change only when the file's folder depth does: the store is at
  /// the root, so a move at the same depth leaves every link working.
  @override
  Future<Result<Relink?, StoreError>> relinkFor(
    Folder folder, {
    required RelPath from,
    required RelPath? toFolder,
  }) async {
    if (from.folders.length ==
        (toFolder == null ? 0 : toFolder.folders.length + 1)) {
      return const Ok(null);
    }
    return switch (await _storeOf(folder).relinkFrom(toFolder)) {
      Ok(value: final relink) => Ok(relink),
      Err(:final error) => Err(error),
    };
  }

  @override
  Future<void> bringBack(String text, Folder folder) =>
      _storeOf(folder).bringBack(ImageNames.namesIn(text));
}
