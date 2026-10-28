import '../conflicts/conflict_source.dart';
import '../filter/file_filter.dart';
import '../scan/folder_scanner.dart';
import '../storage/file_store.dart';
import '../storage/folder_markers.dart';
import 'folder_notices.dart';
import 'sync_adapter.dart';
import 'sync_check.dart';

/// One sync tool the app works with, e.g. Syncthing, or none ("Plain
/// folder"): it recognizes the base folders it syncs and offers their
/// files by its rules. One implementation per tool, each in a package of
/// its own; the app's wiring registers them at compile time.
abstract interface class SyncTool {
  /// Stable and unique among the tools, kept with each base folder, so the
  /// same tool works on it at the next start.
  String get id;

  /// Its file-name rules: the temp files of atomic writes, its own
  /// folders.
  SyncAdapter get rules;

  /// Whether this tool syncs the base folder that [markers] look at, as
  /// far as it can tell.
  Future<SyncStatus> recognize(FolderMarkers markers);

  /// Whether the tool keeps old versions of the base folder's files that
  /// the app can't reach from it, e.g. as it is a subfolder of the synced
  /// folder; for a hint to pick the synced folder itself.
  Future<bool> missesOldVersions(FolderMarkers markers);

  /// The files of one base folder, by this tool's rules, on [store], which
  /// holds only what the app may touch there. [shown] picks the documents;
  /// [markers] look outside, for the tool's own data only;
  /// [pollInterval] tells, at each check of the notices, how often the
  /// folder is polled because changes can't be followed live (`null`: not
  /// polled).
  SyncedFolder open(
    FileStore store, {
    required FileFilter shown,
    required FolderMarkers markers,
    required Duration? Function() pollInterval,
  });
}

/// What a sync tool offers for one base folder.
final class SyncedFolder {
  const SyncedFolder({
    required this.store,
    required this.scanner,
    required this.conflicts,
    required this.notices,
    required this.followed,
  });

  /// The folder's files, read and written by the tool's rules.
  final FileStore store;

  final FolderScanner scanner;
  final ConflictSource conflicts;
  final FolderNotices notices;

  /// The files whose changes count: the shown ones and the tool's records
  /// of them, e.g. their conflict copies.
  final FileFilter followed;
}
