import 'package:truce_core/truce_core.dart';

import '../documents/document.dart';
import '../documents/document_files.dart';
import '../documents/document_title.dart';
import '../folders/document_folder.dart';

/// [documents] as a search sees them: each matches by its folder's name
/// and the names on its path (subfolders and file) from memory, and by
/// its title and text once read through [filesOf].
List<Searchable<Document>> searchablesOf(
  List<Document> documents, {
  required DocumentFiles Function(DocumentFolder folder) filesOf,
}) => [
  for (final document in documents)
    Searchable(
      document,
      names: [document.folder.name, ...document.path.value.split('/')],
      read: () async =>
          switch (await filesOf(document.folder).reload(document)) {
            Ok(value: final read) => (
              title: documentTitle(read.text, read.path, read.type),
              text: read.text,
            ),
            Err() => null,
          },
    ),
];
