import '../changes/bounded_changes.dart';
import '../changes/folder_changes.dart';
import '../changes/live_changes.dart';
import '../storage/bounded_store.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import '../storage/selection.dart';

/// What the app may touch in one base folder, its files and their changes,
/// bounded alike by one [selection] and one [handles] rule, so nothing
/// outside is listed, read, written, deleted or followed.
///
/// Sits between a sync tool's access to the place and the tool's rules on
/// top; see `SyncTool`.
final class BoundedPlace {
  BoundedPlace(
    FileStore files,
    LiveChanges? live,
    this.selection, {
    required this.handles,
    required Duration Function() checkEvery,
  }) : files = BoundedStore(files, selection, handles: handles),
       changes = live == null
           ? null
           : BoundedChanges(
               live,
               files,
               selection,
               counts: handles,
               checkEvery: checkEvery,
             );

  final Selection selection;

  /// Whether a file inside [selection] is listed, written and followed:
  /// the handled file types and the app's own files.
  final bool Function(RelPath file) handles;

  /// See [BoundedStore].
  final FileStore files;

  /// See [BoundedChanges]; `null` where the place can't follow changes
  /// live.
  final FolderChanges? changes;
}
