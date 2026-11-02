import 'package:truce_core/truce_core.dart';

import 'syncthing_sync_check.dart';

/// Where a picked directory lies in Syncthing.
sealed class RootSearch {
  const RootSearch();
}

/// The pick lies in the Syncthing folder at [root] (on the host:
/// [rootHost]), at [pick] inside it (`null`: the root itself).
final class RootFound extends RootSearch {
  const RootFound({
    required this.root,
    required this.rootHost,
    required this.pick,
  });

  final Uri root;
  final Uri rootHost;
  final RelPath? pick;
}

/// No Syncthing folder was found around [picked] (on the host:
/// [pickedHost]): it has no marker, or the app can't look above it.
final class RootNotFound extends RootSearch {
  const RootNotFound({required this.picked, required this.pickedHost});

  final Uri picked;
  final Uri pickedHost;
}

/// Searches upward from [picked] (on the host: [host]) through [markers]
/// for Syncthing's root marker, as far as the app can look.
Future<RootSearch> searchUp(Uri picked, Uri host, FolderMarkers markers) async {
  for (var level = 0; level == 0 || markers.seesParents; level++) {
    switch (await markers.holds(
      SyncthingSyncCheck.rootMarker,
      levelsUp: level,
    )) {
      case true:
        return RootFound(
          root: _up(picked, level),
          rootHost: _up(host, level),
          pick: _last(picked, level),
        );
      case false:
        continue;
      case null:
        return RootNotFound(picked: picked, pickedHost: host);
    }
  }
  return RootNotFound(picked: picked, pickedHost: host);
}

List<String> _segments(Uri address) => [
  for (final segment in address.pathSegments)
    if (segment.isNotEmpty) segment,
];

/// The folder [levels] above [address].
Uri _up(Uri address, int levels) {
  final segments = _segments(address);
  return address.replace(
    pathSegments: segments.sublist(0, segments.length - levels),
  );
}

/// The path of [address] inside the folder [levels] above it.
RelPath? _last(Uri address, int levels) {
  final segments = _segments(address);
  return levels == 0
      ? null
      : RelPath.parse(segments.sublist(segments.length - levels).join('/'));
}
