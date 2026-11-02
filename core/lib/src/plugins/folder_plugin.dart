import '../changes/live_changes.dart';
import '../common/result.dart';
import '../place/bounded_place.dart';
import '../storage/file_store.dart';
import 'open_folder.dart';

/// One kind of folder source, e.g. Syncthing or a local folder: it sets
/// folders up, keeps what it knows of them as its own state, and opens
/// them. One instance per app, registered in the app's wiring; each in a
/// package of its own.
///
/// Its state is saved by the app as an opaque [blob], together with the
/// app's folder list, in one write: so the two never disagree.
abstract interface class FolderPlugin {
  /// Stable and unique among the plugins; part of each folder's id.
  String get id;

  /// The plugin's name, for the UI.
  String get name;

  /// One line on what its folders are, for the list of plugins.
  String get helpLine;

  /// Takes [blob] as its state, as last saved; `null`: none saved yet.
  /// `false` if [blob] can't be read: then it holds no folders and
  /// claims nothing.
  bool load(Object? blob);

  /// Its state, to be saved; read by [load].
  Object? get blob;

  /// The folders it set up.
  List<PluginFolder> get folders;

  /// Sets up the folders [candidates] name, which its add page returned,
  /// in that order; nothing if one of them overlaps a folder already set
  /// up. Changes only its state: the app saves it.
  Result<List<PluginFolder>, AddRefused> add(
    List<PluginFolderCandidate> candidates,
  );

  /// Forgets the folder [id]; its files stay untouched.
  void forget(String id);

  /// The raw access to the folder [id], one of [folders].
  RawFolder open(String id);
}

/// One folder a plugin set up.
final class PluginFolder {
  const PluginFolder({required this.id, required this.location});

  /// The plugin's own id for it; random, stable.
  final String id;

  /// Where it is, for the user, in one line.
  final String location;
}

/// A folder a plugin's add page offers to set up: a plain value. Only the
/// plugin reads [detail].
final class PluginFolderCandidate {
  const PluginFolderCandidate({
    required this.defaultName,
    required this.location,
    required this.detail,
  });

  /// The name the user is offered, e.g. the directory's.
  final String defaultName;

  /// See [PluginFolder.location].
  final String location;

  /// What the plugin needs to set it up; opaque to the app.
  final Object detail;
}

/// Why a plugin set up none of the folders asked.
enum AddRefused {
  /// One of them lies at, inside or around a folder already set up.
  overlaps,
}

/// A plugin's raw access to one folder: its files and changes as they
/// are, which the app bounds, and the plugin's rules on top ([open]).
abstract interface class RawFolder {
  /// All of the folder's files; seen by the app only once bounded.
  FileStore get files;

  /// The folder's changes as they happen; `null` where they can't be
  /// followed live.
  LiveChanges? get changes;

  /// The folder's files by the plugin's rules, on [bounded]: only what the
  /// app may touch there.
  OpenFolder open(BoundedPlace bounded);
}
