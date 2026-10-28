import '../changes/folder_changes.dart';
import '../changes/live_changes.dart';
import '../conflicts/conflict_source.dart';
import '../filter/file_filter.dart';
import '../place/bounded_place.dart';
import '../scan/folder_scanner.dart';
import '../storage/file_store.dart';
import '../storage/subfolder_names.dart';
import 'folder_notices.dart';
import 'sync_check.dart';

/// One sync tool the app works with, e.g. Syncthing, or none ("Plain
/// folder"): it recognizes the base folders it syncs and offers their
/// files by its rules. One implementation per tool, each in a package of
/// its own; the app's wiring registers them at compile time.
///
/// A base folder is known by its address, a URI the tool understands
/// (e.g. `file:` for a folder on this device). Generic code only keeps,
/// compares, shows and hands on an address; only the tool opens it.
abstract interface class SyncTool {
  /// Stable and unique among the tools, kept with each base folder, so the
  /// same tool works on it at the next start.
  String get id;

  /// The tool's name, for the UI.
  String get name;

  /// Whether the folder whose path has the segments [names], outermost
  /// first, is the tool's own (e.g. its version folder) or lies inside it.
  /// Such a folder never holds the user's documents.
  bool isToolFolder(List<String> names);

  /// Whether this tool syncs the base folder at [address], as far as it
  /// can tell. Any address is asked, also one the tool can't open:
  /// [SyncStatus.unknown] then.
  Future<SyncStatus> recognize(Uri address);

  /// Whether the tool keeps old versions of the base folder's files that
  /// the app can't reach from it, e.g. as it is a subfolder of the synced
  /// folder; for a hint to pick the synced folder itself. `false` for an
  /// address the tool can't open.
  Future<bool> missesOldVersions(Uri address);

  /// The tool's access to the base folder at [address], one it
  /// recognized or the user picked it for. Kept as long as the base
  /// folder is; built again only for another address.
  ToolPlace place(Uri address);
}

/// A sync tool's access to one base folder: the bottom of its stack
/// ([files], [changes], [subfolders]), which the app bounds to what its
/// folders show, and the top ([open]), the tool's rules on the bounded
/// part.
abstract interface class ToolPlace {
  /// All of the base folder's files; seen by the app only once bounded.
  FileStore get files;

  /// The base folder's changes as they happen; `null` where they can't be
  /// followed live.
  LiveChanges? get changes;

  /// The folder names in the base folder, for the user to pick subfolders.
  SubfolderNames get subfolders;

  /// The base folder's files by the tool's rules, on [bounded]: only what
  /// the app may touch there (the handled file types and the app's own
  /// files), and its changes bounded alike.
  SyncedFolder open(BoundedPlace bounded);
}

/// What a sync tool offers for one base folder.
final class SyncedFolder {
  const SyncedFolder({
    required this.store,
    required this.scanner,
    required this.conflicts,
    required this.notices,
    required this.changes,
    required this.shown,
  });

  /// The folder's files, read and written by the tool's rules.
  final FileStore store;

  final FolderScanner scanner;
  final ConflictSource conflicts;
  final FolderNotices notices;

  /// The folder's changes as they happen, without the tool's own files;
  /// `null` where they can't be followed live.
  final FolderChanges? changes;

  /// Which files and folders the tool shows: none of its own and no
  /// hidden ones.
  final FileFilter shown;
}
