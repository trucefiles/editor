/// Pictures as files of their own for Truce: which files they are and
/// how the app lists them ([ImageFileType]). They are looked at, never
/// edited, and found by name only.
///
/// Pure Dart, no UI; `core` and `files` know nothing of it. Its view
/// package beside it adds how a picture shows.
library;

export 'src/image_file_support.dart';
export 'src/image_file_type.dart';
