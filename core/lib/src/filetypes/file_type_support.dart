import 'file_type.dart';

/// What the app knows of one file type's files: which they are, by
/// extension.
abstract interface class FileTypeSupport {
  FileType get type;

  /// The extensions of its files, lower case, without the dot (`md`);
  /// a new file takes the first.
  Set<String> get extensions;
}
