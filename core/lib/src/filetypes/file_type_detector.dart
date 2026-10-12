import '../storage/rel_path.dart';
import 'file_type.dart';

/// Tells which [FileType] a file is. The only place that links files to
/// types.
abstract interface class FileTypeDetector {
  /// The type of the file at [path], or `null` if no known type matches.
  FileType? detect(RelPath path);
}
