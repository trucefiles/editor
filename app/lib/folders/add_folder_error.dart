/// Why a folder could not be added.
enum AddFolderError {
  /// The picked folder has no path the app can open.
  unsupportedLocation,

  /// The folder is inside an added folder, or holds one: its documents would
  /// show twice.
  overlaps,

  /// The folder belongs to the sync tool itself (e.g. its version folder),
  /// so it holds no documents.
  syncToolInternal,

  /// The folder list could not be saved.
  notSaved,
}
