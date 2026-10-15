import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'linux/document_portal_paths.dart';

/// Where folders lie on the host system, to tell whether two folders
/// overlap. In a sandbox (e.g. Flatpak) the app may see each picked folder
/// at its own unrelated path.
abstract interface class HostPaths {
  /// The host's path of the folder the app sees at [path]; [path] itself
  /// where the host's path is unknown.
  Future<String> of(String path);
}

/// Platforms where the app sees folders at their host paths.
final class SameHostPaths implements HostPaths {
  const SameHostPaths();

  @override
  Future<String> of(String path) async => path;
}

final hostPathsProvider = Provider<HostPaths>(
  (ref) => Platform.isLinux ? DocumentPortalPaths() : const SameHostPaths(),
);
