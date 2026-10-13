/// Finds the root folder a sync tool syncs a folder from.
///
/// One implementation per sync tool; each knows how its tool marks a
/// root and walks up the parents in its own way.
abstract interface class SyncRootFinder {
  /// Looks for the root of the folder at the absolute [folderPath]: the
  /// folder itself or one of its parents. Without [parentsVisible] (e.g. in
  /// a sandbox), only the folder itself is looked at.
  Future<SyncRootSearch> find(
    String folderPath, {
    required bool parentsVisible,
  });
}

/// Outcome of [SyncRootFinder.find].
sealed class SyncRootSearch {
  const SyncRootSearch();
}

/// The folder is synced from the root at [rootPath].
final class SyncRootFound extends SyncRootSearch {
  const SyncRootFound(this.rootPath);

  final String rootPath;
}

/// No root up to the top folder the app can read: changes likely stay on
/// this device.
final class SyncRootMissing extends SyncRootSearch {
  const SyncRootMissing();
}

/// The search could not see enough (e.g. hidden parents) to tell.
final class SyncRootUnknown extends SyncRootSearch {
  const SyncRootUnknown();
}
