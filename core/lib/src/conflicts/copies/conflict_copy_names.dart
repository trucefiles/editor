/// A sync tool's names for conflict copies that it keeps as files next to
/// their main file, e.g. `todo.sync-conflict-20261003-134809.md` for
/// `todo.md`.
abstract interface class ConflictCopyNames {
  /// What the file name [fileName] tells as a conflict copy; `null` if it
  /// is not one.
  CopyName? parse(String fileName);

  /// The name of a conflict copy of [mainName] made [at] (local time).
  String format(String mainName, DateTime at);
}

/// A conflict copy's name, read: the name of its main file, and when the
/// copy was made.
typedef CopyName = ({String mainName, DateTime createdAt});
