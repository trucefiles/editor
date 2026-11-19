import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';
import 'package:truce_document_image_store/truce_document_image_store.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart' show Relink;

/// The images of a document in [_documentFolder] (`null`: the top
/// level), kept in its folder's [DocumentImageStore].
final class StoreHostImages implements HostImages {
  const StoreHostImages(this._store, this._documentFolder);

  final DocumentImageStore _store;
  final RelPath? _documentFolder;

  @override
  RelPath? keptAt(String link) => switch (ImageNames.nameIn(link)) {
    final name? => ImageNames.pathOf(name),
    null => null,
  };

  @override
  Future<Result<String, StoreError>> add(
    Uint8List bytes, {
    required String extension,
  }) =>
      _store.add(bytes, extension: extension, documentFolder: _documentFolder);

  @override
  Future<Relink?> pasteRelink() async =>
      switch (await _store.relinkFrom(_documentFolder)) {
        Ok(:final value) => value,
        Err() => null,
      };
}
