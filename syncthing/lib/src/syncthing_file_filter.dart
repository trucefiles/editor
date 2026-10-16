import 'package:truce_core/truce_core.dart';

import 'syncthing_conflict_grouping.dart';

/// The files [_shown] includes plus their Syncthing conflict copies, which
/// sit next to them. Leaves out the rest of Syncthing's own files: temp
/// files of any write (Syncthing's and the app's), marker and version
/// folders, as [_shown] does.
final class SyncthingFileFilter implements FileFilter {
  const SyncthingFileFilter(this._shown);

  final FileFilter _shown;

  @override
  bool includesFolder(RelPath folder) => _shown.includesFolder(folder);

  @override
  bool includesFile(RelPath file) {
    if (_shown.includesFile(file)) return true;
    final main = syncthingConflictMain(file);
    return main != null && _shown.includesFile(main);
  }
}
