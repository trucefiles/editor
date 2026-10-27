/// What the platform the app runs on means for document folders. Set once by
/// the platform wiring; read by the sync-tool wiring and settings, so
/// neither tells platforms apart itself.
final class PlatformFacts {
  const PlatformFacts({
    required this.reportsChanges,
    required this.replacesInPlace,
    required this.isPortalFolder,
  });

  /// Whether the platform tells the app about changes other apps make to
  /// files as they happen; otherwise the app can only poll.
  final bool reportsChanges;

  /// Whether files are written in place instead of renamed over: where a
  /// renamed-over file soon shows other apps the old file's modification
  /// time, sync tools would miss the save.
  final bool replacesInPlace;

  /// Whether the folder at a path was handed in through a sandbox's
  /// document portal, which passes on no change events for changes made
  /// outside the sandbox and shows only the picked folder, not what lies
  /// above it.
  final bool Function(String folderPath) isPortalFolder;

  /// Whether the app hears about changes to the folder at [folderPath] as
  /// they happen.
  bool reportsChangesIn(String folderPath) =>
      reportsChanges && !isPortalFolder(folderPath);

  /// Whether the app can read the parent folders of the folder at
  /// [folderPath].
  bool canReadParentsOf(String folderPath) => !isPortalFolder(folderPath);
}
