import '../changes/folder_changes.dart';
import '../changes/live_changes.dart';
import '../conflicts/conflict_source.dart';
import '../place/bounded_place.dart';
import '../scan/folder_scanner.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
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

  /// Whether the folder at [address] is the tool's own (e.g. its version
  /// folder) or lies inside one. Such a folder never holds the user's
  /// documents. Any address is asked, also one the tool can't open:
  /// `false` then.
  bool isToolFolder(Uri address);

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
  /// recognized or the user picked it for. The app keeps one per base
  /// folder it has, as long as it has it; it may build one more for a
  /// short look, e.g. at the folder names of a folder being added.
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

  /// The folder names in the base folder, for the user to pick subfolders:
  /// only the folders it shows.
  SubfolderNames get subfolders;

  /// Whether the tool shows the folder at [folder], and each folder on the
  /// way to it: e.g. none of its own and no hidden one. A folder it doesn't
  /// show never holds the user's documents.
  bool showsFolder(RelPath folder);

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
  });

  /// The folder's files, read and written by the tool's rules.
  final FileStore store;

  final FolderScanner scanner;
  final ConflictSource conflicts;
  final FolderNotices notices;

  /// The folder's changes as they happen, without the tool's own files;
  /// `null` where they can't be followed live.
  final FolderChanges? changes;
}
