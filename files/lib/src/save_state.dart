/// Where an open file's latest content is, for every type of file.
enum SaveState {
  /// Nothing to show: a new file with nothing to keep, or one that
  /// takes no more edits.
  none,

  /// Being edited: the latest edits are only in memory.
  editing,

  /// Kept on this device; not in the folder yet.
  onDevice,

  /// In the file in the folder.
  inFolder,
}
