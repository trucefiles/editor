import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../listed_file.dart';

/// What Recent shows: the [pinned] files, then the [newest] others;
/// [hidesSome] when other files are left out, so All has more to show.
typedef Recent = ({
  List<ListedFile> pinned,
  List<ListedFile> newest,
  bool hidesSome,
});

/// Recent of [files], newest first: every pinned one, and the newest
/// [count] others.
Recent recentOf(
  List<ListedFile> files, {
  required bool Function(ListedFile file) isPinned,
  required int count,
}) {
  final others = files.whereNot(isPinned).toList();
  return (
    pinned: files.where(isPinned).toList(),
    newest: others.take(count).toList(),
    hidesSome: others.length > count,
  );
}

/// The files of one [subfolder] of a [folder] (its top if `null`).
typedef FileSection = ({
  Folder folder,
  RelPath? subfolder,
  List<ListedFile> files,
});

/// [files] by name: a section per folder and subfolder, the folders in
/// the user's order ([folders]; a folder not in it last), then by
/// subfolder path; in each, by file name. Names compare as people read
/// them: case left aside, numbers by value.
List<FileSection> sectionsByName(
  Iterable<ListedFile> files, {
  required List<Folder> folders,
}) {
  final places = {
    for (final (index, folder) in folders.indexed) folder.id: index,
  };
  int placeOf(Folder folder) => places[folder.id] ?? places.length;
  return [
    for (final MapEntry(key: (:folder, :subfolder), value: files) in groupBy(
      files,
      (file) => (folder: file.folder, subfolder: file.path.parent),
    ).entries.sorted((a, b) => _byPlace(a.key, b.key, placeOf)))
      (
        folder: folder,
        subfolder: subfolder,
        files: files.sorted(
          (a, b) => compareAsciiLowerCaseNatural(a.path.name, b.path.name),
        ),
      ),
  ];
}

/// Folders by [placeOf], then by id where two share one; then
/// subfolders by name, a folder's top first.
int _byPlace(
  ({Folder folder, RelPath? subfolder}) a,
  ({Folder folder, RelPath? subfolder}) b,
  int Function(Folder folder) placeOf,
) => switch (placeOf(a.folder).compareTo(placeOf(b.folder))) {
  0 when a.folder.id != b.folder.id => a.folder.id.compareTo(b.folder.id),
  0 => compareAsciiLowerCaseNatural(
    a.subfolder?.value ?? '',
    b.subfolder?.value ?? '',
  ),
  final byPlace => byPlace,
};
