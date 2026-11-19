import '../changes/bounded_changes.dart';
import '../changes/folder_changes.dart';
import '../changes/live_changes.dart';
import '../storage/bounded_store.dart';
import '../storage/closing_store.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';

/// What the app may touch in one folder, its files and their changes,
/// bounded alike by one [handles] rule, so no other file is listed,
/// written, deleted or followed; and closed alike by [close]. Files the
/// app keeps apart (e.g. the files its documents link) are reached only
/// through [apart].
///
/// Sits between a plugin's raw access to the folder and the plugin's rules
/// on top; see `RawFolder`.
final class BoundedPlace {
  factory BoundedPlace(
    FileStore files,
    LiveChanges? live, {
    required bool Function(RelPath file) handles,
    bool Function(RelPath path) keptApart = _nothingApart,
    required Duration Function() checkEvery,
  }) {
    final gate = ClosingStore(files);
    bool counts(RelPath file) => handles(file) && !keptApart(file);
    return BoundedPlace._(
      gate,
      BoundedStore(gate, handles: counts, enters: (f) => !keptApart(f)),
      BoundedStore(gate, handles: keptApart),
      live == null
          ? null
          : BoundedChanges(live, gate, counts: counts, checkEvery: checkEvery),
    );
  }

  BoundedPlace._(this._gate, this.files, this.apart, this.changes);

  static bool _nothingApart(RelPath path) => false;

  final ClosingStore _gate;

  /// See [BoundedStore]; never lists, walks or writes what is kept
  /// apart.
  final FileStore files;

  /// The files kept apart, by the `keptApart` rule handed in from above
  /// (true for a kept folder and all inside it): listed, created and
  /// deleted only there, read like any file; never followed. Core never
  /// knows what they are.
  final FileStore apart;

  /// See [BoundedChanges]; `null` where the folder can't be followed live.
  final FolderChanges? changes;

  /// From now on, [files] answers [StoreError.closed]; done once what is
  /// under way is.
  Future<void> close() => _gate.close();
}
