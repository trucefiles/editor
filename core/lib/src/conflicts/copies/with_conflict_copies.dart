import '../../filter/file_filter.dart';
import '../../storage/rel_path.dart';
import 'conflict_copy_grouping.dart';
import 'conflict_copy_names.dart';

/// The files [_shown] includes plus their conflict copies, named by
/// [_names], which sit next to them.
final class WithConflictCopies implements FileFilter {
  const WithConflictCopies(this._shown, this._names);

  final FileFilter _shown;
  final ConflictCopyNames _names;

  @override
  bool includesFolder(RelPath folder) => _shown.includesFolder(folder);

  @override
  bool includesFile(RelPath file) {
    if (_shown.includesFile(file)) return true;
    final main = conflictCopyMain(file, _names);
    return main != null && _shown.includesFile(main);
  }
}
