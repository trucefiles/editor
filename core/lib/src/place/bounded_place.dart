import '../changes/bounded_changes.dart';
import '../changes/folder_changes.dart';
import '../changes/live_changes.dart';
import '../storage/bounded_store.dart';
import '../storage/closing_store.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import 'file_bounds.dart';

/// What the app may touch in one folder, its files and their changes,
/// bounded alike by one rule ([FileBounds.shows]), so no other file is
/// listed, written, deleted or followed; and closed alike by [close].
/// Files the app keeps apart are reached only through [apart].
///
/// Sits between a plugin's raw access to the folder and the plugin's rules
/// on top; see `RawFolder`.
final class BoundedPlace {
  factory BoundedPlace(
    FileStore files,
    LiveChanges? live, {
    required FileBounds bounds,
    required Duration Function() checkEvery,
  }) {
    final gate = ClosingStore(files);
    return BoundedPlace._(
      gate,
      BoundedStore(
        gate,
        handles: bounds.shows,
        enters: (folder) => !bounds.keptApart(folder),
      ),
      BoundedStore(gate, handles: bounds.keptApart),
      live == null
          ? null
          : BoundedChanges(
              live,
              gate,
              counts: bounds.shows,
              checkEvery: checkEvery,
            ),
      bounds,
    );
  }

  BoundedPlace._(
    this._gate,
    this.files,
    this.apart,
    this.changes,
    this._bounds,
  );

  final ClosingStore _gate;
  final FileBounds _bounds;

  /// Whether the folder at [folder] may hold files of [files]: none at
  /// or inside what is kept apart.
  bool holdsFilesIn(RelPath folder) => !_bounds.keptApart(folder);

  /// See [BoundedStore]; never lists, walks or writes what is kept
  /// apart.
  final FileStore files;

  /// The files kept apart ([FileBounds.keptApart]): listed, created and
  /// deleted only there, read like any file; never followed.
  final FileStore apart;

  /// See [BoundedChanges]; `null` where the folder can't be followed live.
  final FolderChanges? changes;

  /// From now on, [files] answers [StoreError.closed]; done once what is
  /// under way is.
  Future<void> close() => _gate.close();
}
