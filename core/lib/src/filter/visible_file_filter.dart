import '../storage/rel_path.dart';
import 'file_filter.dart';

/// Skips hidden files and folders (dotfiles) and the sync tool's own files
/// ([isInternal]). Which file types count is the bounded layer's job.
final class VisibleFileFilter implements FileFilter {
  const VisibleFileFilter(this._isInternal);

  final bool Function(RelPath path) _isInternal;

  @override
  bool includesFolder(RelPath folder) => _isVisible(folder);

  @override
  bool includesFile(RelPath file) => _isVisible(file);

  bool _isVisible(RelPath path) =>
      !path.name.startsWith('.') && !_isInternal(path);
}
