import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:truce_core/truce_core.dart';

import '../conflicts/folder_conflicts.dart';
import '../listed_file.dart';

/// Which files home shows: those in one of the [folders] picked and of
/// one of the [types] picked; nothing picked in either shows them all.
@immutable
final class HomeFilter {
  const HomeFilter({this.folders = const {}, this.types = const {}});

  /// The folders whose files show; empty: every folder.
  final Set<FolderId> folders;

  /// The types of the files that show; empty: every type.
  final Set<FileType> types;

  /// Those of [files] that show, in their order.
  List<ListedFile> of(List<ListedFile> files) => [
    for (final file in files)
      if (_shows(file.folder.id, file.type.type)) file,
  ];

  /// Those of [orphans] that show, in their order, by their main file;
  /// [typeOf] tells the type of a file at a path, `null` if none.
  List<FolderConflict> orphansOf(
    List<FolderConflict> orphans, {
    required FileType? Function(RelPath path) typeOf,
  }) => [
    for (final orphan in orphans)
      if (_shows(orphan.folder.id, typeOf(orphan.conflict.mainPath))) orphan,
  ];

  /// Whether a file in [folder] of [type] shows; a file of no known
  /// type shows only while every type does.
  bool _shows(FolderId folder, FileType? type) =>
      (folders.isEmpty || folders.contains(folder)) &&
      (types.isEmpty || types.contains(type));

  @override
  bool operator ==(Object other) =>
      other is HomeFilter &&
      const SetEquality<FolderId>().equals(other.folders, folders) &&
      const SetEquality<FileType>().equals(other.types, types);

  @override
  int get hashCode => Object.hash(
    const SetEquality<FolderId>().hash(folders),
    const SetEquality<FileType>().hash(types),
  );
}
