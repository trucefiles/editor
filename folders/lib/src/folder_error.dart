/// Why a change to the folder list was refused or failed.
enum FolderError {
  /// The folder shares subfolders with another one, or its base folder
  /// lies inside an added base folder or holds one: its files would
  /// show twice.
  overlaps,

  /// The folder belongs to the sync tool itself (e.g. its version folder),
  /// so it holds no files.
  syncToolInternal,

  /// The folder list could not be saved.
  notSaved,
}
