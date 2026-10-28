import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart';

import '../../folders/document_folder.dart';
import '../document.dart';

/// What Recent shows: the [pinned] documents, then the [newest] others.
typedef Recent = ({List<Document> pinned, List<Document> newest});

/// Recent of [documents], newest first: every pinned one, and the newest
/// [count] others.
Recent recentOf(
  List<Document> documents, {
  required bool Function(Document document) isPinned,
  required int count,
}) => (
  pinned: documents.where(isPinned).toList(),
  newest: documents.whereNot(isPinned).take(count).toList(),
);

/// The documents of one [subfolder] of a [folder] (its top if `null`).
typedef DocumentSection = ({
  DocumentFolder folder,
  RelPath? subfolder,
  List<Document> documents,
});

/// [documents] by name: a section per folder and subfolder, by folder name
/// and then subfolder path; in each, by file name. Names compare as
/// people read them: case left aside, numbers by value.
List<DocumentSection> sectionsByName(Iterable<Document> documents) => [
  for (final MapEntry(key: (:folder, :subfolder), value: documents) in groupBy(
    documents,
    (document) => (folder: document.folder, subfolder: document.path.parent),
  ).entries.sorted((a, b) => _byPlace(a.key, b.key)))
    (
      folder: folder,
      subfolder: subfolder,
      documents: documents.sorted(
        (a, b) => compareAsciiLowerCaseNatural(a.path.name, b.path.name),
      ),
    ),
];

int _byPlace(
  ({DocumentFolder folder, RelPath? subfolder}) a,
  ({DocumentFolder folder, RelPath? subfolder}) b,
) => switch (compareAsciiLowerCaseNatural(a.folder.name, b.folder.name)) {
  0 when a.folder.id != b.folder.id => a.folder.id.compareTo(b.folder.id),
  0 => compareAsciiLowerCaseNatural(
    a.subfolder?.value ?? '',
    b.subfolder?.value ?? '',
  ),
  final byName => byName,
};

/// Those of [documents] the folder filter shows: the ones in the folder
/// with id [folderId], or all if `null`.
List<Document> filteredBy(String? folderId, List<Document> documents) => [
  for (final document in documents)
    if (folderId == null || document.folder.id == folderId) document,
];
