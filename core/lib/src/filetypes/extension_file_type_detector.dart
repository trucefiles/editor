import '../storage/rel_path.dart';
import 'file_type.dart';
import 'file_type_detector.dart';

/// Markdown documents and checklists.
const markdownFileType = FileType('markdown');

/// Detects the [FileType] by file extension, ignoring case.
final class ExtensionFileTypeDetector implements FileTypeDetector {
  /// [types] maps lower-case extensions without the dot, e.g. `md`.
  const ExtensionFileTypeDetector(this._types);

  /// The types Truce handles today.
  const ExtensionFileTypeDetector.standard()
    : this(const {'md': markdownFileType});

  final Map<String, FileType> _types;

  @override
  FileType? detect(RelPath path) {
    final name = path.name;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? null : _types[name.substring(dot + 1).toLowerCase()];
  }
}
