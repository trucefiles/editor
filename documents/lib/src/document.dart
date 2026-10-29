import 'package:meta/meta.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

/// One document file, as listed: where it is, its type, version and time;
/// never its text (see `DocumentText`).
@immutable
final class Document {
  const Document({
    required this.folder,
    required this.path,
    required this.type,
    required this.version,
    required this.modified,
  });

  /// The folder it shows in, found from its path.
  final DocumentFolder folder;

  /// Where it is in [folder]'s base folder.
  final RelPath path;

  /// Its file type, as the type's support reads it.
  final FileTypeSupport<Object?> type;

  /// Its version on disk.
  final FileVersion version;

  /// When the file was last changed, for showing and sorting.
  final DateTime modified;

  DocumentKey get key => (baseId: folder.base.id, path: path);

  @override
  bool operator ==(Object other) =>
      other is Document &&
      other.folder == folder &&
      other.path == path &&
      other.type == type &&
      other.version == version &&
      other.modified == modified;

  @override
  int get hashCode => Object.hash(folder, path, type, version, modified);
}

/// Identifies a document across rescans and folder changes: its base
/// folder, by id, and its path there.
typedef DocumentKey = ({String baseId, RelPath path});
