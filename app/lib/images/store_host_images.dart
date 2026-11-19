import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';
import 'package:truce_document_image_store/truce_document_image_store.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';

/// The images of the document open in [_session], kept in its folder's
/// [DocumentImageStore] (by [_storeOf]).
final class StoreHostImages implements HostImages {
  const StoreHostImages(this._storeOf, this._session);

  final DocumentImageStore Function(FolderId folder) _storeOf;
  final FileSession _session;

  @override
  RelPath? keptAt(String link) => switch (ImageNames.nameIn(link)) {
    final name? => ImageNames.pathOf(name),
    null => null,
  };

  /// Kept and linked where the document is then, with no place change
  /// in between.
  @override
  Future<Result<void, StoreError>> add(
    Uint8List bytes, {
    required String extension,
    required void Function(String link) insert,
  }) => _session.atPlace((file, path) async {
    final added = await _storeOf(file.folder.id)
        .add(bytes, extension: extension, documentFolder: path.parent);
    if (added case Ok(value: final link)) insert(link);
    return added.map((_) {});
  });
}
