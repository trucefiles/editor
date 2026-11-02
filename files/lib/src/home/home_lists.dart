import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../listed_file.dart';

/// What Recent shows: the [pinned] files, then the [newest] others.
typedef Recent = ({List<ListedFile> pinned, List<ListedFile> newest});

/// Recent of [files], newest first: every pinned one, and the newest
/// [count] others.
Recent recentOf(
  List<ListedFile> files, {
  required bool Function(ListedFile file) isPinned,
  required int count,
}) => (
  pinned: files.where(isPinned).toList(),
  newest: files.whereNot(isPinned).take(count).toList(),
);

/// The files of one [subfolder] of a [folder] (its top if `null`).
typedef FileSection = ({
  Folder folder,
  RelPath? subfolder,
  List<ListedFile> files,
});

/// [files] by name: a section per folder and subfolder, by folder name
/// and then subfolder path; in each, by file name. Names compare as
/// people read them: case left aside, numbers by value.
List<FileSection> sectionsByName(Iterable<ListedFile> files) => [
  for (final MapEntry(key: (:folder, :subfolder), value: files) in groupBy(
    files,
    (file) => (folder: file.folder, subfolder: file.path.parent),
  ).entries.sorted((a, b) => _byPlace(a.key, b.key)))
    (
      folder: folder,
      subfolder: subfolder,
      files: files.sorted(
        (a, b) => compareAsciiLowerCaseNatural(a.path.name, b.path.name),
      ),
    ),
];

int _byPlace(
  ({Folder folder, RelPath? subfolder}) a,
  ({Folder folder, RelPath? subfolder}) b,
) => switch (compareAsciiLowerCaseNatural(a.folder.name, b.folder.name)) {
  0 when a.folder.id != b.folder.id => a.folder.id.compareTo(b.folder.id),
  0 => compareAsciiLowerCaseNatural(
    a.subfolder?.value ?? '',
    b.subfolder?.value ?? '',
  ),
  final byName => byName,
};
