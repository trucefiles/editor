import 'package:truce_core/truce_core.dart';

/// One Syncthing folder (a root) the app knows: where the app sees it,
/// and where it lies on the host, to compare it with other areas.
final class SyncthingRoot {
  const SyncthingRoot({
    required this.id,
    required this.address,
    required this.host,
  });

  final String id;

  /// Where the app opens it.
  final Uri address;

  /// Its host path, resolved once as it was added.
  final Uri host;

  /// Its name, for the user: its last path segment.
  String get name => lastSegment(address);

  Map<String, Object> toJson() => {
    'id': id,
    'address': '$address',
    'host': '$host',
  };

  static SyncthingRoot? fromJson(Object? json) => switch (json) {
    {
      'id': final String id,
      'address': final String address,
      'host': final String host,
    } =>
      switch ((savedFileAddress(address), savedFileAddress(host))) {
        (final address?, final host?) => SyncthingRoot(
          id: id,
          address: address,
          host: host,
        ),
        _ => null,
      },
    _ => null,
  };
}

/// One app folder in a Syncthing folder: its root and the directory inside
/// it (`null`: the root itself).
final class SyncthingDirectory {
  const SyncthingDirectory({
    required this.id,
    required this.root,
    required this.path,
  });

  final String id;

  /// The id of its [SyncthingRoot].
  final String root;

  final RelPath? path;

  Map<String, Object> toJson() => {
    'id': id,
    'root': root,
    if (path case final path?) 'path': path.value,
  };

  static SyncthingDirectory? fromJson(Object? json) => switch (json) {
    {'id': final String id, 'root': final String root}
        when FolderId.isPart(id) =>
      switch (json) {
        {'path': final String raw} => switch (RelPath.parse(raw)) {
          final path? => SyncthingDirectory(id: id, root: root, path: path),
          null => null,
        },
        {'path': _} => null,
        _ => SyncthingDirectory(id: id, root: root, path: null),
      },
    _ => null,
  };
}

/// What the Syncthing plugin knows: its roots and its folders, each in one
/// root. Its blob, as the app saves it:
///
/// ```json
/// {"roots": [{"id": "r1", "address": "file:///home/me/Sync",
///             "host": "file:///home/me/Sync"}],
///  "folders": [{"id": "f1", "root": "r1", "path": "work"},
///              {"id": "f2", "root": "r1"}]}
/// ```
final class SyncthingState {
  SyncthingState({
    Map<String, SyncthingRoot> roots = const {},
    Map<String, SyncthingDirectory> folders = const {},
  }) : roots = Map.unmodifiable(roots),
       folders = Map.unmodifiable(folders);

  static final empty = SyncthingState();

  /// By id.
  final Map<String, SyncthingRoot> roots;

  /// By id, in the order added.
  final Map<String, SyncthingDirectory> folders;

  /// The folders in the root [rootId].
  Iterable<SyncthingDirectory> foldersIn(String rootId) =>
      folders.values.where((folder) => folder.root == rootId);

  Object toJson() => {
    'roots': [for (final root in roots.values) root.toJson()],
    'folders': [for (final folder in folders.values) folder.toJson()],
  };

  /// `null` if [json] is not a state [toJson] wrote: e.g. a folder of an
  /// unknown root.
  static SyncthingState? fromJson(Object? json) {
    if (json case {
      'roots': final List<Object?> rawRoots,
      'folders': final List<Object?> rawFolders,
    }) {
      final roots = rawRoots.map(SyncthingRoot.fromJson).toList();
      final folders = rawFolders.map(SyncthingDirectory.fromJson).toList();
      if (roots.contains(null) || folders.contains(null)) return null;
      final state = SyncthingState(
        roots: {for (final root in roots.nonNulls) root.id: root},
        folders: {for (final folder in folders.nonNulls) folder.id: folder},
      );
      final consistent =
          state.roots.length == roots.length &&
          state.folders.length == folders.length &&
          state.folders.values.every(
            (folder) => state.roots.containsKey(folder.root),
          );
      return consistent ? state : null;
    }
    return null;
  }
}

/// The folder [path] inside the folder at [address].
Uri addressInside(Uri address, RelPath? path) => path == null
    ? address
    : address.replace(
        pathSegments: [
          for (final segment in address.pathSegments)
            if (segment.isNotEmpty) segment,
          ...path.value.split('/'),
        ],
      );
