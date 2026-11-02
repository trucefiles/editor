import 'package:meta/meta.dart';
import 'package:truce_core/truce_core.dart';

import '../listed_file.dart';

/// Which files home shows: those in one [folder] and of one [type];
/// `null` for either shows them all.
@immutable
final class FileFilter {
  const FileFilter({this.folder, this.type});

  /// The folder whose files show; `null`: every folder.
  final FolderId? folder;

  /// The type of the files that show; `null`: every type.
  final FileType? type;

  /// Whether a file in [folder] of [type] shows; a file of no known
  /// type shows only while every type does.
  bool shows(FolderId folder, FileType? type) =>
      (this.folder == null || this.folder == folder) &&
      (this.type == null || this.type == type);

  /// Those of [files] that show, in their order.
  List<ListedFile> of(List<ListedFile> files) => [
    for (final file in files)
      if (shows(file.folder.id, file.type.type)) file,
  ];

  @override
  bool operator ==(Object other) =>
      other is FileFilter && other.folder == folder && other.type == type;

  @override
  int get hashCode => Object.hash(folder, type);
}
