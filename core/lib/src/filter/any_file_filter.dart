import '../storage/rel_path.dart';
import 'file_filter.dart';

/// Includes what any of its filters includes, e.g. the files the app shows
/// plus the files that hold their marks.
final class AnyFileFilter implements FileFilter {
  const AnyFileFilter(this._filters);

  final List<FileFilter> _filters;

  @override
  bool includesFolder(RelPath folder) =>
      _filters.any((filter) => filter.includesFolder(folder));

  @override
  bool includesFile(RelPath file) =>
      _filters.any((filter) => filter.includesFile(file));
}
