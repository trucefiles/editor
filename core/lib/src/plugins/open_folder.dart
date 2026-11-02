import '../changes/folder_changes.dart';
import '../common/result.dart';
import '../conflicts/conflict_source.dart';
import '../place/bounded_place.dart';
import '../scan/folder_scanner.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import 'folder_notices.dart';
import 'move_by_copy.dart';

/// One folder the app has open: the one owner of its I/O, made by its
/// plugin's rules on top of the [BoundedPlace] the app gave them.
final class OpenFolder {
  /// [settle] waits for what the plugin's rules still have under way, e.g.
  /// a rewrite due shortly after a save.
  OpenFolder(
    this._bounded, {
    required this.store,
    required this.scanner,
    required this.conflicts,
    required this.notices,
    required this.changes,
    this._settle,
  });

  final BoundedPlace _bounded;
  final Future<void> Function()? _settle;

  /// The folder's files, read and written by the plugin's rules.
  final FileStore store;

  final FolderScanner scanner;
  final ConflictSource conflicts;

  /// What the user should know about the folder; its one home.
  final FolderNotices notices;

  /// The folder's changes as they happen, without the plugin's own files;
  /// `null` where they can't be followed live.
  final FolderChanges? changes;

  /// Moves the file at [from], at version [ifUnchanged], to [to] in
  /// [target] (this folder too): the one call for every move. For now by
  /// the shared copy and delete ([moveByCopy]); a plugin with a cheaper
  /// way may take it here later.
  Future<Result<FileEntry, MoveError>> moveInto(
    RelPath from, {
    required FileVersion ifUnchanged,
    required OpenFolder target,
    required RelPath to,
  }) => moveByCopy(
    store,
    from,
    ifUnchanged: ifUnchanged,
    target: target.store,
    to: to,
  );

  /// Waits for the work under way, the plugin's included, then refuses
  /// everything with [StoreError.closed].
  Future<void> close() async {
    await _settle?.call();
    await _bounded.close();
  }
}
