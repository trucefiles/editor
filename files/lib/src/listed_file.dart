import 'package:meta/meta.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

/// One file, as listed: where it is, its type, version and time;
/// never its text (see `FileText`).
@immutable
final class ListedFile {
  const ListedFile({
    required this.folder,
    required this.path,
    required this.type,
    required this.version,
    required this.modified,
  });

  /// The folder it is in.
  final Folder folder;

  /// Where it is in [folder].
  final RelPath path;

  /// Its file type, as the type's support reads it.
  final FileTypeSupport<Object?> type;

  /// Its version on disk.
  final FileVersion version;

  /// When the file was last changed, for showing and sorting.
  final DateTime modified;

  FileKey get key => (folder: folder.id, path: path);

  @override
  bool operator ==(Object other) =>
      other is ListedFile &&
      other.folder == folder &&
      other.path == path &&
      other.type == type &&
      other.version == version &&
      other.modified == modified;

  @override
  int get hashCode => Object.hash(folder, path, type, version, modified);
}

/// Identifies a file across rescans and folder changes: its folder, by
/// id, and its path there.
typedef FileKey = ({FolderId folder, RelPath path});
