import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../document.dart';
import '../document_files.dart';
import '../document_title.dart';

/// [documents] as a search sees them: each matches by its folder's name,
/// its subfolders' names and its file name without the extension (or
/// "md" would find every document) from memory, and by its title and
/// text once read through [filesOf].
List<Searchable<Document>> searchablesOf(
  List<Document> documents, {
  required DocumentFiles Function(DocumentFolder folder) filesOf,
}) => [
  for (final document in documents)
    Searchable(
      document,
      names: [
        document.folder.name,
        ...?document.path.parent?.value.split('/'),
        nameTitle(document.path),
      ],
      read: () async =>
          switch (await filesOf(document.folder).reload(document)) {
            Ok(value: final read) => (
              title: titleOf(read.summary, read.path),
              text: read.text,
            ),
            Err() => null,
          },
    ),
];
