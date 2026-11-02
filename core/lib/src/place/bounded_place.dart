import '../changes/bounded_changes.dart';
import '../changes/folder_changes.dart';
import '../changes/live_changes.dart';
import '../storage/bounded_store.dart';
import '../storage/closing_store.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';

/// What the app may touch in one folder, its files and their changes,
/// bounded alike by one [handles] rule, so no other file is listed,
/// written, deleted or followed; and closed alike by [close].
///
/// Sits between a plugin's raw access to the folder and the plugin's rules
/// on top; see `RawFolder`.
final class BoundedPlace {
  factory BoundedPlace(
    FileStore files,
    LiveChanges? live, {
    required bool Function(RelPath file) handles,
    required Duration Function() checkEvery,
  }) {
    final gate = ClosingStore(files);
    return BoundedPlace._(
      gate,
      BoundedStore(gate, handles: handles),
      live == null
          ? null
          : BoundedChanges(live, gate, counts: handles, checkEvery: checkEvery),
    );
  }

  BoundedPlace._(this._gate, this.files, this.changes);

  final ClosingStore _gate;

  /// See [BoundedStore].
  final FileStore files;

  /// See [BoundedChanges]; `null` where the folder can't be followed live.
  final FolderChanges? changes;

  /// From now on, [files] answers [StoreError.closed]; done once what is
  /// under way is.
  Future<void> close() => _gate.close();
}
