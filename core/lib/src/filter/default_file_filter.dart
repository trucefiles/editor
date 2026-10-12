import '../filetypes/file_type_detector.dart';
import '../storage/rel_path.dart';
import '../sync/sync_adapter.dart';
import 'file_filter.dart';

/// Skips hidden files and folders (dotfiles), the sync tool's own files,
/// and files of no known type.
final class DefaultFileFilter implements FileFilter {
  const DefaultFileFilter(this._syncAdapter, this._detector);

  final SyncAdapter _syncAdapter;
  final FileTypeDetector _detector;

  @override
  bool includesFolder(RelPath folder) => _isVisible(folder);

  @override
  bool includesFile(RelPath file) =>
      _isVisible(file) && _detector.detect(file) != null;

  bool _isVisible(RelPath path) =>
      !path.name.startsWith('.') && !_syncAdapter.isInternal(path);
}
