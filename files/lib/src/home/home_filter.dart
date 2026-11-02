import 'package:meta/meta.dart';
import 'package:truce_core/truce_core.dart';

import '../conflicts/folder_conflicts.dart';
import '../listed_file.dart';

/// Which files home shows: those in one [folder] and of one [type];
/// `null` for either shows them all.
@immutable
final class HomeFilter {
  const HomeFilter({this.folder, this.type});

  /// The folder whose files show; `null`: every folder.
  final FolderId? folder;

  /// The type of the files that show; `null`: every type.
  final FileType? type;

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
      (this.folder == null || this.folder == folder) &&
      (this.type == null || this.type == type);

  @override
  bool operator ==(Object other) =>
      other is HomeFilter && other.folder == folder && other.type == type;

  @override
  int get hashCode => Object.hash(folder, type);
}
