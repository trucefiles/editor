import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../file_title.dart';
import '../files_of_folder.dart';
import '../listed_file.dart';
import '../shown_file_types.dart';

/// [files] as a search sees them: each matches by its folder's name,
/// its subfolders' names and its file name without the extension (or
/// "md" would find every file) from memory, and by its title and
/// text once read through [filesOf], as its type gives it ([types]).
List<Searchable<ListedFile>> searchablesOf(
  List<ListedFile> files, {
  required FilesOfFolder Function(Folder folder) filesOf,
  required ShownFileTypes types,
}) => [
  for (final file in files)
    Searchable(
      file,
      names: [
        file.folder.name,
        ...?file.path.parent?.value.split('/'),
        nameTitle(file.path),
      ],
      read: () async => switch (await filesOf(file.folder).reload(file)) {
        Ok(value: final read) => (
          title: titleOf(read.summary, read.path),
          text: types.ofFile(read.type).searchText(read),
        ),
        Err() => null,
      },
    ),
];
