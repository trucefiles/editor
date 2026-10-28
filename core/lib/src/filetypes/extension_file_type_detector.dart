import '../storage/rel_path.dart';
import 'file_type.dart';
import 'file_type_detector.dart';
import 'file_type_support.dart';

/// Detects the [FileType] by file extension, ignoring case.
final class ExtensionFileTypeDetector implements FileTypeDetector {
  /// [types] maps lower-case extensions without the dot, e.g. `md`.
  const ExtensionFileTypeDetector(this._types);

  /// The types of [supports], by their extensions.
  ExtensionFileTypeDetector.of(Iterable<FileTypeSupport<Object?>> supports)
    : this({
        for (final support in supports)
          for (final extension in support.extensions) extension: support.type,
      });

  final Map<String, FileType> _types;

  @override
  FileType? detect(RelPath path) {
    final name = path.name;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? null : _types[name.substring(dot + 1).toLowerCase()];
  }
}
