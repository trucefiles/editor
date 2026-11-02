/// Why a change to the folder list was refused or failed.
enum FolderError {
  /// The folder lies at, inside or around one already added: its files
  /// would show twice.
  overlaps,

  /// The folder list could not be saved: nothing changed.
  notSaved,
}
