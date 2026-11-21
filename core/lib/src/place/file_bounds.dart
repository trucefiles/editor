import '../storage/rel_path.dart';

/// Which files of a folder the app touches: those it [handles], except
/// those it keeps apart ([keptApart]: true for a kept folder and all
/// inside it, e.g. the files its documents link), which it reaches only
/// on their own. Core never knows what either is.
final class FileBounds {
  const FileBounds({required this.handles, required this.keptApart});

  final bool Function(RelPath file) handles;
  final bool Function(RelPath path) keptApart;

  /// Whether [file] is one of the folder's files the app shows as a file:
  /// listed, followed, and backed up as one.
  bool shows(RelPath file) => handles(file) && !keptApart(file);

  /// Whether files the app shows may go in the folder at [folder]: not
  /// at or inside what is kept apart.
  bool holdsFilesIn(RelPath folder) => !keptApart(folder);
}
