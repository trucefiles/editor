import 'package:collection/collection.dart';

import 'host_paths.dart';

/// The areas of this device's disk each disk plugin claims, as host
/// paths: e.g. Syncthing its folders' roots, Local folder its folders.
/// Holds the one rule across plugins: an area never lies at, inside or
/// around another plugin's, so no file is in two plugins' folders.
///
/// Each plugin tells its whole set as it changes; a plugin that can't
/// read its state claims nothing.
final class DiskAreas {
  final _byPlugin = <String, Set<Uri>>{};

  /// [plugin]'s areas are now [hostPaths].
  void claim(String plugin, Iterable<Uri> hostPaths) =>
      _byPlugin[plugin] = {...hostPaths};

  /// Whether [hostPath] lies at, inside or around an area of another
  /// plugin than [plugin].
  bool clashes(String plugin, Uri hostPath) =>
      clashOf(plugin, hostPath) != null;

  /// The area of another plugin than [plugin] that [hostPath] lies at,
  /// inside or around; `null` if none.
  Uri? clashOf(String plugin, Uri hostPath) => [
    for (final MapEntry(key: owner, value: areas) in _byPlugin.entries)
      if (owner != plugin) ...areas,
  ].firstWhereOrNull((area) => nests(area, hostPath));
}
