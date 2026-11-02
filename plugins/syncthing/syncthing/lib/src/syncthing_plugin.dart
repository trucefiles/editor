import 'dart:math';

import 'package:truce_core/truce_core.dart';

import 'syncthing_folder.dart';
import 'syncthing_root_search.dart';
import 'syncthing_state.dart';

/// Syncthing as a folder plugin, for folders on this device: each app
/// folder is one directory in a Syncthing folder (its root), kept with
/// that root, which tells whether Syncthing syncs it. Its roots are its
/// areas on [_disk]; one root goes with its last folder.
final class SyncthingPlugin implements FolderPlugin {
  SyncthingPlugin(this._disk, {String Function()? newId})
    : _newId = newId ?? _randomId;

  final LocalDisk _disk;
  final String Function() _newId;
  SyncthingState _state = SyncthingState.empty;

  @override
  String get id => 'syncthing';

  @override
  String get name => 'Syncthing';

  @override
  String get helpLine => 'Folders synced with Syncthing';

  @override
  bool load(Object? blob) {
    final state = blob == null
        ? SyncthingState.empty
        : SyncthingState.fromJson(blob);
    _set(state ?? SyncthingState.empty);
    return state != null;
  }

  @override
  Object? get blob => _state.toJson();

  @override
  List<PluginFolder> get folders => [
    for (final folder in _state.folders.values) _pluginFolder(folder),
  ];

  /// Where [picked] lies in Syncthing: in a root the plugin knows (by host
  /// path, so also where the app can't look above the pick), else in the
  /// first folder upward with Syncthing's marker.
  Future<RootSearch> findRoot(Uri picked) async {
    final host = await _disk.hostPathOf(picked);
    for (final root in _state.roots.values) {
      if (isSameFolder(root.host, host)) {
        return RootFound(root: root.address, rootHost: root.host, pick: null);
      }
      if (segmentsInside(host, root.host) case final inside?) {
        return RootFound(
          root: root.address,
          rootHost: root.host,
          pick: RelPath.parse(inside.join('/')),
        );
      }
    }
    return searchUp(picked, host, _disk.markersAt(picked));
  }

  /// The folders in the root at [root] to pick from: none hidden, none of
  /// Syncthing's own.
  SubfolderNames subfoldersOf(Uri root) => _disk
      .subfoldersAt(root)
      .shownBy(SyncthingFolder.shown.includesFolderPath);

  /// Whether a folder at [path] in a root is one the user may pick: shown
  /// by Syncthing, and none of its own.
  bool shows(RelPath? path) =>
      path == null || SyncthingFolder.shown.includesFolderPath(path);

  /// The folders already set up in the root at [rootHost], by their path
  /// in it (`null`: the root itself).
  Set<RelPath?> takenIn(Uri rootHost) => {
    for (final root in _state.roots.values)
      if (isSameFolder(root.host, rootHost))
        for (final folder in _state.foldersIn(root.id)) folder.path,
  };

  /// Whether a root at [rootHost] would lie at, inside or around another
  /// plugin's area, or inside or around another root.
  bool rootClashes(Uri rootHost) =>
      _disk.areas.clashes(id, rootHost) ||
      _state.roots.values.any(
        (root) =>
            !isSameFolder(root.host, rootHost) && nests(root.host, rootHost),
      );

  /// The folder [path] in the root at [root] (on the host: [rootHost]),
  /// to set up.
  PluginFolderCandidate candidate(Uri root, Uri rootHost, RelPath? path) =>
      PluginFolderCandidate(
        defaultName: path?.name ?? lastSegment(root),
        location: _location(lastSegment(root), rootHost, path),
        detail: _Pick(root, rootHost, path).toJson(),
      );

  @override
  Result<List<PluginFolder>, AddRefused> add(
    List<PluginFolderCandidate> candidates,
  ) {
    var state = _state;
    final added = <SyncthingDirectory>[];
    for (final candidate in candidates) {
      final pick = _Pick.fromJson(candidate.detail);
      final known = state.roots.values
          .where((root) => isSameFolder(root.host, pick.rootHost))
          .firstOrNull;
      if (known == null && _clashesIn(state, pick.rootHost)) {
        return const Err(AddRefused.overlaps);
      }
      final root =
          known ??
          SyncthingRoot(id: _newId(), address: pick.root, host: pick.rootHost);
      if (state
          .foldersIn(root.id)
          .any((folder) => _nestedPaths(folder.path, pick.path))) {
        return const Err(AddRefused.overlaps);
      }
      final folder = SyncthingDirectory(
        id: _newId(),
        root: root.id,
        path: pick.path,
      );
      added.add(folder);
      state = SyncthingState(
        roots: {...state.roots, root.id: root},
        folders: {...state.folders, folder.id: folder},
      );
    }
    _set(state);
    return Ok([for (final folder in added) _pluginFolder(folder)]);
  }

  @override
  void forget(String id) {
    final gone = _state.folders[id];
    if (gone == null) return;
    final folders = {..._state.folders}..remove(id);
    _set(
      SyncthingState(
        roots: {
          for (final root in _state.roots.values)
            if (root.id != gone.root ||
                folders.values.any((folder) => folder.root == root.id))
              root.id: root,
        },
        folders: folders,
      ),
    );
  }

  @override
  RawFolder open(String id) {
    final folder = _state.folders[id]!;
    final root = _state.roots[folder.root]!;
    return SyncthingFolder(
      _disk.open(
        addressInside(root.address, folder.path),
        tempName: SyncthingFolder.rules.tempFileName,
      ),
      _disk.markersAt(root.address),
    );
  }

  /// Takes [state] and claims its roots.
  void _set(SyncthingState state) {
    _state = state;
    _disk.areas.claim(id, [for (final root in state.roots.values) root.host]);
  }

  /// Whether a new root at [rootHost] clashes with [state]'s roots or
  /// another plugin's areas.
  bool _clashesIn(SyncthingState state, Uri rootHost) =>
      _disk.areas.clashes(id, rootHost) ||
      state.roots.values.any((root) => nests(root.host, rootHost));

  PluginFolder _pluginFolder(SyncthingDirectory folder) {
    final root = _state.roots[folder.root]!;
    return PluginFolder(
      id: folder.id,
      location: _location(root.name, root.host, folder.path),
    );
  }

  /// Where a folder is: its directory's host path, and its root.
  static String _location(String rootName, Uri rootHost, RelPath? path) {
    final directory = addressInside(rootHost, path);
    final shown = directory.isScheme('file')
        ? directory.toFilePath()
        : '$directory';
    return '$shown (Syncthing folder $rootName)';
  }

  static bool _nestedPaths(RelPath? a, RelPath? b) =>
      a == null || b == null || a == b || a.isInside(b) || b.isInside(a);

  static final _random = Random.secure();

  static String _randomId() =>
      List.generate(12, (_) => _random.nextInt(16).toRadixString(16)).join();
}

/// What a candidate holds for the plugin: the root and the path in it.
final class _Pick {
  const _Pick(this.root, this.rootHost, this.path);

  final Uri root;
  final Uri rootHost;
  final RelPath? path;

  Object toJson() => {
    'root': '$root',
    'host': '$rootHost',
    if (path case final path?) 'path': path.value,
  };

  /// Only ever of a candidate this plugin made, so anything else is a bug.
  static _Pick fromJson(Object detail) => switch (detail) {
    {'root': final String root, 'host': final String host} => _Pick(
      Uri.parse(root),
      Uri.parse(host),
      switch (detail['path']) {
        final String raw => RelPath.parse(raw),
        _ => null,
      },
    ),
    _ => throw ArgumentError.value(detail, 'detail', 'not a Syncthing pick'),
  };
}
