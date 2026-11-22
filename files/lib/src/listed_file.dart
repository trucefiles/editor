import 'package:meta/meta.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

/// One file, as listed: where it is, its type, version, time and size;
/// never its text (see `FileText`).
@immutable
final class ListedFile {
  const ListedFile({
    required this.folder,
    required this.path,
    required this.type,
    required this.version,
    required this.modified,
    required this.size,
  });

  /// The folder it is in.
  final Folder folder;

  /// Where it is in [folder].
  final RelPath path;

  /// Its file type, as the type's support reads it.
  final FileTypeSupport type;

  /// Its version on disk.
  final FileVersion version;

  /// When the file was last changed, for showing and sorting.
  final DateTime modified;

  /// How many bytes the file holds, as last listed or written: what was
  /// saved, not edits still in memory.
  final int size;

  FileKey get key => (folder: folder.id, path: path);

  @override
  bool operator ==(Object other) =>
      other is ListedFile &&
      other.folder == folder &&
      other.path == path &&
      other.type == type &&
      other.version == version &&
      other.modified == modified &&
      other.size == size;

  @override
  int get hashCode => Object.hash(folder, path, type, version, modified, size);
}

/// Identifies a file across rescans and folder changes: its folder, by
/// id, and its path there.
typedef FileKey = ({FolderId folder, RelPath path});
